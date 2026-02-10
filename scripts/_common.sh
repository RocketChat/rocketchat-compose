#!/usr/bin/env bash
# shellcheck disable=SC2034
# Shared library for Rocket.Chat stack management scripts
# Source this file — do not execute directly.

set -euo pipefail

# ── Colors & Logging ────────────────────────────────────────────────
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[1;33m'
_BLUE='\033[0;34m'
_BOLD='\033[1m'
_NC='\033[0m' # No Color

log_info()  { printf "${_BLUE}[INFO]${_NC}  %s\n" "$*"; }
log_ok()    { printf "${_GREEN}[ OK ]${_NC}  %s\n" "$*"; }
log_warn()  { printf "${_YELLOW}[WARN]${_NC}  %s\n" "$*" >&2; }
log_error() { printf "${_RED}[ERR ]${_NC}  %s\n" "$*" >&2; }

# ── Resolve Repo Root ───────────────────────────────────────────────
# All compose files use relative paths (./files/) so we must cd to repo root.
get_repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  # Scripts live at repo_root/ or repo_root/scripts/
  if [[ -f "${script_dir}/compose.yml" ]]; then
    echo "${script_dir}"
  elif [[ -f "${script_dir}/../compose.yml" ]]; then
    echo "$(cd "${script_dir}/.." && pwd)"
  else
    log_error "Cannot find compose.yml — run this script from the repo root or scripts/ directory"
    exit 1
  fi
}

REPO_ROOT="$(get_repo_root)"
cd "${REPO_ROOT}"

# ── Container Runtime Detection ─────────────────────────────────────
detect_runtime() {
  if command -v docker &>/dev/null; then
    CONTAINER_RUNTIME="docker"
  elif command -v podman &>/dev/null; then
    CONTAINER_RUNTIME="podman"
  else
    log_error "Neither docker nor podman found. Install one and try again."
    exit 1
  fi
}

detect_compose() {
  # Try "docker compose" (v2 plugin) first, then "docker-compose", then "podman-compose"
  if ${CONTAINER_RUNTIME} compose version &>/dev/null 2>&1; then
    COMPOSE_CMD="${CONTAINER_RUNTIME} compose"
  elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
  elif command -v podman-compose &>/dev/null; then
    COMPOSE_CMD="podman-compose"
  else
    log_error "No compose command found. Install 'docker compose' plugin or 'docker-compose'."
    exit 1
  fi
}

check_daemon() {
  if ! ${CONTAINER_RUNTIME} info &>/dev/null 2>&1; then
    log_error "${CONTAINER_RUNTIME} daemon is not running."
    exit 1
  fi
}

run_checks() {
  detect_runtime
  detect_compose
  check_daemon
}

# ── .env Handling ───────────────────────────────────────────────────
# Returns 0 if .env exists, 1 if it was just created (caller should exit).
ensure_env_file() {
  if [[ -f "${REPO_ROOT}/.env" ]]; then
    return 0
  fi

  if [[ ! -f "${REPO_ROOT}/.env.example" ]]; then
    log_error ".env.example not found — cannot create .env"
    exit 1
  fi

  cp "${REPO_ROOT}/.env.example" "${REPO_ROOT}/.env"
  log_warn "────────────────────────────────────────────────────────"
  log_warn ".env file was missing — created from .env.example"
  log_warn ""
  log_warn "Review and update .env before deploying, especially:"
  log_warn "  DOMAIN, ROOT_URL, REG_TOKEN, LETSENCRYPT_EMAIL"
  log_warn ""
  log_warn "Then re-run this command."
  log_warn "────────────────────────────────────────────────────────"
  return 1
}

# Lightweight version: create .env silently if missing (needed for 'down'
# because compose.traefik.yml has ${LETSENCRYPT_EMAIL?...} which errors
# on parse even during 'down').
ensure_env_file_for_down() {
  if [[ ! -f "${REPO_ROOT}/.env" ]]; then
    if [[ -f "${REPO_ROOT}/.env.example" ]]; then
      cp "${REPO_ROOT}/.env.example" "${REPO_ROOT}/.env"
      log_warn ".env was missing — created from .env.example so compose can parse traefik config"
    fi
  fi
}

# ── Component Flag Parsing ──────────────────────────────────────────
# Sets boolean variables: INCLUDE_DATABASE, INCLUDE_MONITORING, INCLUDE_TRAEFIK, INCLUDE_APP
# Call parse_component_flags "$@" then shift $SHIFTED_COUNT
INCLUDE_DATABASE=true
INCLUDE_MONITORING=true
INCLUDE_TRAEFIK=true
INCLUDE_APP=true
SHIFTED_COUNT=0

parse_component_flags() {
  # Reset
  INCLUDE_DATABASE=true
  INCLUDE_MONITORING=true
  INCLUDE_TRAEFIK=true
  INCLUDE_APP=true
  SHIFTED_COUNT=0

  local _remaining_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-monitoring)
        INCLUDE_MONITORING=false
        ;;
      --no-traefik)
        INCLUDE_TRAEFIK=false
        ;;
      --monitoring-only)
        INCLUDE_MONITORING=true
        INCLUDE_TRAEFIK=false
        INCLUDE_APP=false
        ;;
      --traefik-only)
        INCLUDE_MONITORING=false
        INCLUDE_TRAEFIK=true
        INCLUDE_APP=false
        ;;
      --database-only)
        INCLUDE_MONITORING=false
        INCLUDE_TRAEFIK=false
        INCLUDE_APP=false
        ;;
      --app-only)
        INCLUDE_MONITORING=false
        INCLUDE_TRAEFIK=false
        ;;
      *)
        _remaining_args+=("$1")
        ;;
    esac
    shift
  done

  # Rebuild positional parameters with remaining args
  REMAINING_ARGS=("${_remaining_args[@]+"${_remaining_args[@]}"}")
}

# ── Compose File Builder ────────────────────────────────────────────
# Builds COMPOSE_FILES array based on INCLUDE_* booleans
build_compose_files() {
  COMPOSE_FILES=()

  # Database is always included — MongoDB + NATS are hard deps
  if [[ "${INCLUDE_DATABASE}" == "true" ]]; then
    if [[ ! -f "${REPO_ROOT}/compose.database.yml" ]]; then
      log_error "compose.database.yml not found"
      exit 1
    fi
    COMPOSE_FILES+=("-f" "compose.database.yml")
  fi

  if [[ "${INCLUDE_MONITORING}" == "true" ]]; then
    if [[ ! -f "${REPO_ROOT}/compose.monitoring.yml" ]]; then
      log_error "compose.monitoring.yml not found"
      exit 1
    fi
    COMPOSE_FILES+=("-f" "compose.monitoring.yml")
  fi

  if [[ "${INCLUDE_TRAEFIK}" == "true" ]]; then
    if [[ ! -f "${REPO_ROOT}/compose.traefik.yml" ]]; then
      log_error "compose.traefik.yml not found"
      exit 1
    fi
    COMPOSE_FILES+=("-f" "compose.traefik.yml")
  fi

  if [[ "${INCLUDE_APP}" == "true" ]]; then
    if [[ ! -f "${REPO_ROOT}/compose.yml" ]]; then
      log_error "compose.yml not found"
      exit 1
    fi
    COMPOSE_FILES+=("-f" "compose.yml")
  fi

  if [[ ${#COMPOSE_FILES[@]} -eq 0 ]]; then
    log_error "No compose files selected — nothing to do"
    exit 1
  fi
}

# ── Compose Runner ──────────────────────────────────────────────────
# Execute compose command from repo root with the built file list.
# Usage: run_compose up -d
run_compose() {
  log_info "Running: ${COMPOSE_CMD} ${COMPOSE_FILES[*]} $*"
  # shellcheck disable=SC2086
  ${COMPOSE_CMD} "${COMPOSE_FILES[@]}" "$@"
}

# ── Component Summary ───────────────────────────────────────────────
print_component_summary() {
  local action="${1:-}"
  echo ""
  log_info "Components${action:+ (${action})}:"
  [[ "${INCLUDE_DATABASE}" == "true" ]]   && log_info "  - Database (MongoDB + NATS)"
  [[ "${INCLUDE_MONITORING}" == "true" ]] && log_info "  - Monitoring (Prometheus, Grafana, Loki)"
  [[ "${INCLUDE_TRAEFIK}" == "true" ]]    && log_info "  - Traefik (Reverse Proxy + TLS)"
  [[ "${INCLUDE_APP}" == "true" ]]        && log_info "  - Rocket.Chat"
  echo ""
}

# ── Access URL Printer ──────────────────────────────────────────────
print_access_urls() {
  if [[ ! -f "${REPO_ROOT}/.env" ]]; then
    return
  fi

  # Source .env to get variable values (subshell to avoid polluting)
  local root_url domain grafana_path grafana_domain grafana_host_port
  root_url=$(grep -E '^ROOT_URL=' "${REPO_ROOT}/.env" | cut -d= -f2- | tr -d '"' || echo "")
  domain=$(grep -E '^DOMAIN=' "${REPO_ROOT}/.env" | cut -d= -f2- | tr -d '"' || echo "")
  grafana_path=$(grep -E '^GRAFANA_PATH=' "${REPO_ROOT}/.env" | cut -d= -f2- | tr -d '"' || echo "")
  grafana_domain=$(grep -E '^GRAFANA_DOMAIN=' "${REPO_ROOT}/.env" | cut -d= -f2- | tr -d '"' || echo "")
  grafana_host_port=$(grep -E '^GRAFANA_HOST_PORT=' "${REPO_ROOT}/.env" | cut -d= -f2- | tr -d '"' || echo "5050")

  echo ""
  log_ok "Stack is starting up!"
  echo ""
  if [[ -n "${root_url}" && "${INCLUDE_APP}" == "true" ]]; then
    log_info "Rocket.Chat:  ${root_url}"
  fi
  if [[ "${INCLUDE_MONITORING}" == "true" ]]; then
    if [[ -n "${grafana_domain}" ]]; then
      log_info "Grafana:      http://${grafana_domain}"
    elif [[ -n "${grafana_path}" && -n "${root_url}" ]]; then
      log_info "Grafana:      ${root_url}${grafana_path}  (or http://localhost:${grafana_host_port}${grafana_path})"
    else
      log_info "Grafana:      http://localhost:${grafana_host_port}"
    fi
  fi
  echo ""
}
