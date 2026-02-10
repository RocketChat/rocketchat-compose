#!/usr/bin/env bash
# Bring the Rocket.Chat stack down
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Stop the Rocket.Chat stack.

Component flags:
  --no-monitoring     Exclude monitoring from the stop command
  --no-traefik        Exclude Traefik from the stop command
  --monitoring-only   Stop only monitoring services
  --traefik-only      Stop only Traefik services
  --database-only     Stop only database services
  --app-only          Stop only Rocket.Chat + database

Options:
  -v, --volumes       Remove named volumes (with confirmation prompt)
  --remove-orphans    Remove containers for services not in compose files
  --timeout SECS      Shutdown timeout in seconds (default: 10)
  -h, --help          Show this help message

Examples:
  $(basename "$0")                        # Stop full stack
  $(basename "$0") -v                     # Stop and remove volumes (prompts)
  $(basename "$0") --no-traefik           # Stop everything except Traefik
  $(basename "$0") --timeout 30           # Stop with 30s timeout
EOF
  exit 0
}

# ── Source shared library ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/scripts/_common.sh" ]]; then
  # shellcheck source=scripts/_common.sh
  source "${SCRIPT_DIR}/scripts/_common.sh"
elif [[ -f "${SCRIPT_DIR}/_common.sh" ]]; then
  # shellcheck source=scripts/_common.sh
  source "${SCRIPT_DIR}/_common.sh"
else
  echo "ERROR: Cannot find scripts/_common.sh" >&2
  exit 1
fi

# ── Parse arguments ─────────────────────────────────────────────────
VOLUMES=false
REMOVE_ORPHANS=false
TIMEOUT=""

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage ;;
  esac
done

parse_component_flags "$@"
set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--volumes)       VOLUMES=true ;;
    --remove-orphans)   REMOVE_ORPHANS=true ;;
    --timeout)
      shift
      if [[ $# -eq 0 ]]; then
        log_error "--timeout requires a value"
        exit 1
      fi
      TIMEOUT="$1"
      ;;
    -h|--help) usage ;;
    *)
      log_error "Unknown option: $1"
      usage
      ;;
  esac
  shift
done

# ── Preflight ───────────────────────────────────────────────────────
run_checks

# For 'down', compose.traefik.yml has ${LETSENCRYPT_EMAIL?...} which causes
# a hard parse error even during teardown. Auto-create .env if needed.
if [[ "${INCLUDE_TRAEFIK}" == "true" ]]; then
  ensure_env_file_for_down
fi

build_compose_files
print_component_summary "stopping"

# ── Volume removal confirmation ─────────────────────────────────────
if [[ "${VOLUMES}" == "true" ]]; then
  log_warn "This will DELETE all named volumes (including database data)!"
  printf "${_YELLOW}Are you sure? [y/N]: ${_NC}"
  read -r confirm
  if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
    log_info "Aborted."
    exit 0
  fi
fi

# ── Build down args ─────────────────────────────────────────────────
DOWN_ARGS=("down")
[[ "${VOLUMES}" == "true" ]]        && DOWN_ARGS+=("--volumes")
[[ "${REMOVE_ORPHANS}" == "true" ]] && DOWN_ARGS+=("--remove-orphans")
[[ -n "${TIMEOUT}" ]]               && DOWN_ARGS+=("--timeout" "${TIMEOUT}")

# ── Stop stack ──────────────────────────────────────────────────────
run_compose "${DOWN_ARGS[@]}"
log_ok "Stack stopped."
