#!/usr/bin/env bash
# Show status of the Rocket.Chat stack
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Show the status of Rocket.Chat stack containers.

Component flags:
  --no-monitoring     Exclude monitoring from status
  --no-traefik        Exclude Traefik from status
  --monitoring-only   Show only monitoring services
  --traefik-only      Show only Traefik services
  --database-only     Show only database services
  --app-only          Show only Rocket.Chat + database

Options:
  -h, --help          Show this help message

Examples:
  $(basename "$0")                        # Show all container status
  $(basename "$0") --no-monitoring        # Show status without monitoring
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
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage ;;
  esac
done

parse_component_flags "$@"
set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"

while [[ $# -gt 0 ]]; do
  case "$1" in
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

# Status needs .env for traefik compose parsing (same issue as down)
if [[ "${INCLUDE_TRAEFIK}" == "true" ]]; then
  ensure_env_file_for_down
fi

build_compose_files

# ── Show status ─────────────────────────────────────────────────────
echo ""
log_info "Container status:"
echo ""
run_compose ps -a
echo ""
