#!/usr/bin/env bash
# Restart the Rocket.Chat stack
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Restart the Rocket.Chat stack.

Component flags:
  --no-monitoring     Exclude monitoring
  --no-traefik        Exclude Traefik
  --monitoring-only   Restart only monitoring services
  --traefik-only      Restart only Traefik services
  --database-only     Restart only database services
  --app-only          Restart only Rocket.Chat + database

Options:
  --pull              Pull latest images before restarting
  --timeout SECS      Shutdown timeout in seconds (default: 10)
  --rolling           Rolling restart (recreate without full down, shorter downtime)
  -h, --help          Show this help message

Examples:
  $(basename "$0")                        # Full restart (down + up)
  $(basename "$0") --rolling              # Recreate containers in-place
  $(basename "$0") --pull                 # Pull images then restart
  $(basename "$0") --no-monitoring        # Restart without monitoring
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
PULL=false
TIMEOUT=""
ROLLING=false

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage ;;
  esac
done

parse_component_flags "$@"
set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pull)       PULL=true ;;
    --rolling)    ROLLING=true ;;
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

if ! ensure_env_file; then
  exit 1
fi

build_compose_files
print_component_summary "restarting"

# ── Pull images ─────────────────────────────────────────────────────
if [[ "${PULL}" == "true" ]]; then
  log_info "Pulling latest images..."
  run_compose pull
fi

# ── Restart ─────────────────────────────────────────────────────────
if [[ "${ROLLING}" == "true" ]]; then
  log_info "Rolling restart (recreating containers in-place)..."
  UP_ARGS=("up" "-d" "--force-recreate")
  [[ -n "${TIMEOUT}" ]] && UP_ARGS+=("--timeout" "${TIMEOUT}")
  run_compose "${UP_ARGS[@]}"
else
  log_info "Full restart (down + up)..."

  DOWN_ARGS=("down")
  [[ -n "${TIMEOUT}" ]] && DOWN_ARGS+=("--timeout" "${TIMEOUT}")
  run_compose "${DOWN_ARGS[@]}"

  run_compose up -d
fi

print_access_urls
