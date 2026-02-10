#!/usr/bin/env bash
# Bring the Rocket.Chat stack up
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Start the Rocket.Chat stack.

Component flags:
  --no-monitoring     Exclude monitoring (Prometheus, Grafana, Loki)
  --no-traefik        Exclude Traefik reverse proxy
  --monitoring-only   Start only database + monitoring
  --traefik-only      Start only database + Traefik
  --database-only     Start only database (MongoDB + NATS)
  --app-only          Start only database + Rocket.Chat (no monitoring/traefik)

Options:
  --pull              Pull latest images before starting
  --no-detach         Run in foreground (don't pass -d to compose)
  -h, --help          Show this help message

Examples:
  $(basename "$0")                        # Start full stack
  $(basename "$0") --no-monitoring        # Start without monitoring
  $(basename "$0") --pull                 # Pull images then start
  $(basename "$0") --database-only        # Start only MongoDB + NATS
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
DETACH=true

# Check for --help before component parsing
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
    --no-detach)  DETACH=false ;;
    -h|--help)    usage ;;
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
print_component_summary "starting"

# ── Pull images ─────────────────────────────────────────────────────
if [[ "${PULL}" == "true" ]]; then
  log_info "Pulling latest images..."
  run_compose pull
fi

# ── Start stack ─────────────────────────────────────────────────────
UP_ARGS=("up")
if [[ "${DETACH}" == "true" ]]; then
  UP_ARGS+=("-d")
fi

run_compose "${UP_ARGS[@]}"

if [[ "${DETACH}" == "true" ]]; then
  print_access_urls
fi
