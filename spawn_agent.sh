#!/usr/bin/env bash
set -euo pipefail

# ============================================
# OpenClaw Agent Spawner
# Creates a fully configured agent directory
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${SCRIPT_DIR}/deployed_agents"
TEMPLATE_COMPOSE="${SCRIPT_DIR}/docker-compose.template.yml"
TEMPLATE_ENV="${SCRIPT_DIR}/.env.template"

# --- Help ---
usage() {
    echo -e "${BOLD}🐙 OpenClaw Agent Spawner${NC}"
    echo
    echo -e "Usage: ${CYAN}./spawn_agent.sh <agent-name> <port>${NC}"
    echo
    echo -e "Arguments:"
    echo -e "  ${BOLD}agent-name${NC}   Unique name for the agent (alphanumeric, hyphens, underscores)"
    echo -e "  ${BOLD}port${NC}         Host port to expose (1024-65535)"
    echo
    echo -e "Examples:"
    echo -e "  ./spawn_agent.sh research-bot 18801"
    echo -e "  ./spawn_agent.sh code-reviewer 18802"
    echo
    echo -e "Each agent is created under ${CYAN}deployed_agents/<agent-name>/${NC}"
    exit 0
}

# --- Helpers ---
die() { echo -e "${RED}✖ Error:${NC} $1" >&2; exit 1; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }
ok() { echo -e "${GREEN}✔${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# --- Parse args ---
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage
[[ $# -ne 2 ]] && die "Expected 2 arguments: <agent-name> <port>\n  Run with --help for usage."

AGENT_NAME="$1"
PORT="$2"

# --- Validate agent name ---
[[ "$AGENT_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || \
    die "Invalid agent name '${AGENT_NAME}'. Use alphanumeric characters, hyphens, and underscores only."

# --- Validate port ---
[[ "$PORT" =~ ^[0-9]+$ ]] || die "Port must be a number."
(( PORT >= 1024 && PORT <= 65535 )) || die "Port must be between 1024 and 65535."

# --- Check if agent already exists ---
AGENT_DIR="${DEPLOY_DIR}/${AGENT_NAME}"
[[ -d "$AGENT_DIR" ]] && die "Agent '${AGENT_NAME}' already exists at ${AGENT_DIR}"

# --- Check if port is in use ---
if command -v lsof &>/dev/null; then
    if lsof -i :"$PORT" &>/dev/null; then
        die "Port ${PORT} is already in use. Pick a different port."
    fi
elif command -v ss &>/dev/null; then
    if ss -tlnp | grep -q ":${PORT} "; then
        die "Port ${PORT} is already in use. Pick a different port."
    fi
fi

# --- Check templates exist ---
[[ -f "$TEMPLATE_COMPOSE" ]] || die "Missing docker-compose.template.yml"
[[ -f "$TEMPLATE_ENV" ]] || die "Missing .env.template"

# --- Ensure fleet network exists ---
docker network inspect openclaw-fleet >/dev/null 2>&1 || docker network create openclaw-fleet
ok "Fleet network ready (openclaw-fleet)"

# --- Generate gateway token ---
GATEWAY_TOKEN=$(openssl rand -hex 32)

# --- Create agent directory ---
info "Spawning agent ${BOLD}${AGENT_NAME}${NC} on port ${BOLD}${PORT}${NC}..."

mkdir -p "${AGENT_DIR}/workspace" "${AGENT_DIR}/config"

# --- Generate docker-compose.yml from template ---
sed -e "s/{{AGENT_NAME}}/${AGENT_NAME}/g" \
    -e "s/{{PORT}}/${PORT}/g" \
    "$TEMPLATE_COMPOSE" > "${AGENT_DIR}/docker-compose.yml"
ok "Created docker-compose.yml"

# --- Copy and configure .env ---
cp "$TEMPLATE_ENV" "${AGENT_DIR}/.env"
cat >> "${AGENT_DIR}/.env" <<EOF

# --- Agent-Specific (auto-generated) ---
OPENCLAW_AGENT_NAME=${AGENT_NAME}
OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
GATEWAY_TOKEN=${GATEWAY_TOKEN}
EOF
ok "Created .env with gateway token"

# --- Success card ---
echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}🐙 Agent spawned successfully!${NC}                       ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}Name:${NC}  ${AGENT_NAME}$(printf '%*s' $((38 - ${#AGENT_NAME})) '')${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}Port:${NC}  ${PORT}$(printf '%*s' $((38 - ${#PORT})) '')${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}URL:${NC}   http://localhost:${PORT}$(printf '%*s' $((27 - ${#PORT})) '')${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}Token:${NC} ${GATEWAY_TOKEN:0:16}...$(printf '%*s' 22 '')${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${YELLOW}Launch:${NC}                                            ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  cd deployed_agents/${AGENT_NAME}$(printf '%*s' $((28 - ${#AGENT_NAME})) '')${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  docker compose up -d$(printf '%*s' 30 '')${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo
info "Don't forget to set your ${BOLD}ANTHROPIC_API_KEY${NC} in ${CYAN}${AGENT_DIR}/.env${NC}"
