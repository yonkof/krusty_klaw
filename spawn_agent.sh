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

# --- Detect --auto flag ---
AUTO_MODE=false
for arg in "$@"; do
    [[ "$arg" == "--auto" ]] && AUTO_MODE=true
done

# --- Help ---
usage() {
    echo -e "${BOLD}🐙 OpenClaw Agent Spawner${NC}"
    echo
    echo -e "Usage: ${CYAN}./spawn_agent.sh <agent-name> [port] [--auto]${NC}"
    echo
    echo -e "Arguments:"
    echo -e "  ${BOLD}agent-name${NC}   Unique name for the agent (alphanumeric, hyphens, underscores)"
    echo -e "  ${BOLD}port${NC}         (Optional) Host port to expose (1024-65535)."
    echo -e "               If omitted, auto-selects the next available port by scanning"
    echo -e "               existing agents. Starts at 18790 if no agents exist."
    echo
    echo -e "Flags:"
    echo -e "  ${BOLD}--auto${NC}       Skip interactive prompts; inject API keys from .env.template"
    echo -e "               automatically if they contain real (non-placeholder) values."
    echo -e "               Pulls the image and launches the container without user input."
    echo
    echo -e "Examples:"
    echo -e "  ./spawn_agent.sh my-agent              # auto-picks next available port"
    echo -e "  ./spawn_agent.sh research-bot 18795     # uses port 18795"
    echo -e "  ./spawn_agent.sh code-reviewer 18795 --auto  # port 18795, auto mode"
    echo
    echo -e "Each agent is created under ${CYAN}deployed_agents/<agent-name>/${NC}"
    exit 0
}

# --- Helpers ---
die() { echo -e "${RED}✖ Error:${NC} $1" >&2; exit 1; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }
ok() { echo -e "${GREEN}✔${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# --- Parse args (filter out flags) ---
POSITIONAL=()
for arg in "$@"; do
    case "$arg" in
        --auto) ;;
        --help|-h) usage ;;
        *) POSITIONAL+=("$arg") ;;
    esac
done

[[ ${#POSITIONAL[@]} -lt 1 || ${#POSITIONAL[@]} -gt 2 ]] && die "Expected 1-2 arguments: <agent-name> [port]\n  Run with --help for usage."

AGENT_NAME="${POSITIONAL[0]}"

# --- Determine port (auto-increment or explicit) ---
if [[ ${#POSITIONAL[@]} -ge 2 ]]; then
    PORT="${POSITIONAL[1]}"
else
    # Auto-detect: scan deployed agents for highest port, increment by 1
    DEFAULT_PORT=18790
    HIGHEST_PORT=0
    if [[ -d "$DEPLOY_DIR" ]]; then
        for compose_file in "${DEPLOY_DIR}"/*/docker-compose.yml; do
            [[ -f "$compose_file" ]] || continue
            # Extract host port from "HOST:CONTAINER" mapping
            FOUND_PORT=$(grep -oP '^\s*-\s*"\K[0-9]+(?=:)' "$compose_file" 2>/dev/null | head -1)
            if [[ -n "$FOUND_PORT" && "$FOUND_PORT" -gt "$HIGHEST_PORT" ]]; then
                HIGHEST_PORT="$FOUND_PORT"
            fi
        done
    fi
    if (( HIGHEST_PORT > 0 )); then
        PORT=$(( HIGHEST_PORT + 1 ))
    else
        PORT=$DEFAULT_PORT
    fi
    info "Auto-selected port ${BOLD}${PORT}${NC}"
fi

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

mkdir -p "${AGENT_DIR}/workspace" "${AGENT_DIR}/config" "${AGENT_DIR}/scripts"

# --- Generate docker-compose.yml from template ---
sed -e "s/{{AGENT_NAME}}/${AGENT_NAME}/g" \
    -e "s/{{PORT}}/${PORT}/g" \
    "$TEMPLATE_COMPOSE" > "${AGENT_DIR}/docker-compose.yml"
ok "Created docker-compose.yml"

# --- Copy bootstrap script and manifests ---
cp "${SCRIPT_DIR}/scripts/bootstrap.sh" "${AGENT_DIR}/scripts/bootstrap.sh"
chmod +x "${AGENT_DIR}/scripts/bootstrap.sh"
cp "${SCRIPT_DIR}/requirements.txt" "${AGENT_DIR}/requirements.txt"
cp "${SCRIPT_DIR}/apt-packages.txt" "${AGENT_DIR}/apt-packages.txt"
ok "Copied bootstrap script and package manifests"

# --- Copy and configure .env ---
cp "$TEMPLATE_ENV" "${AGENT_DIR}/.env"
cat >> "${AGENT_DIR}/.env" <<EOF

# --- Agent-Specific (auto-generated) ---
OPENCLAW_AGENT_NAME=${AGENT_NAME}
OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
GATEWAY_TOKEN=${GATEWAY_TOKEN}
EOF
ok "Created .env with gateway token"

# ============================================
# Onboarding Flow
# ============================================

# Helper: read a key value from .env.template (skips comments, placeholders)
read_template_key() {
    local key="$1"
    local val
    val=$(grep -E "^${key}=" "$TEMPLATE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
    # Trim whitespace
    val="${val## }"
    val="${val%% }"
    # Return empty if placeholder or empty
    if [[ -z "$val" || "$val" == your-*-here || "$val" == "your_"* || "$val" == "sk-"* && ${#val} -lt 10 ]]; then
        echo ""
    else
        echo "$val"
    fi
}

# Helper: inject a key into the agent's .env file
inject_key() {
    local key="$1" val="$2"
    if grep -qE "^${key}=" "${AGENT_DIR}/.env"; then
        sed -i "s|^${key}=.*|${key}=${val}|" "${AGENT_DIR}/.env"
    else
        echo "${key}=${val}" >> "${AGENT_DIR}/.env"
    fi
}

# Helper: launch the container
launch_container() {
    info "Pulling latest OpenClaw image..."
    (cd "${AGENT_DIR}" && docker compose pull 2>&1) || warn "Pull failed — will use cached image if available"
    info "Launching agent container..."
    (cd "${AGENT_DIR}" && docker compose up -d)
    ok "Container ${BOLD}openclaw-${AGENT_NAME}${NC} is running"
}

# Helper: show success card — "live" variant
show_live_card() {
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}🐙 Agent is live! Born Ready 🚀${NC}                     ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}Name:${NC}  ${AGENT_NAME}$(printf '%*s' $((38 - ${#AGENT_NAME})) '')${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}Port:${NC}  ${PORT}$(printf '%*s' $((38 - ${#PORT})) '')${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}URL:${NC}   http://localhost:${PORT}$(printf '%*s' $((27 - ${#PORT})) '')${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}Token:${NC} ${GATEWAY_TOKEN:0:16}...$(printf '%*s' 22 '')${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}Your agent is live! 🎉${NC}$(printf '%*s' 30 '')${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo
}

# Helper: show success card — "onboarding needed" variant
show_onboarding_card() {
    local ATTACH_CMD="docker exec -it openclaw-${AGENT_NAME} npx openclaw configure"
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}🐙 Agent spawned — onboarding needed${NC}                ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}Name:${NC}  ${AGENT_NAME}$(printf '%*s' $((38 - ${#AGENT_NAME})) '')${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}Port:${NC}  ${PORT}$(printf '%*s' $((38 - ${#PORT})) '')${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}URL:${NC}   http://localhost:${PORT}$(printf '%*s' $((27 - ${#PORT})) '')${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}Token:${NC} ${GATEWAY_TOKEN:0:16}...$(printf '%*s' 22 '')${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${YELLOW}Complete onboarding:${NC}                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}${ATTACH_CMD}${NC}$(printf '%*s' $((44 - ${#ATTACH_CMD})) '')${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo
}

# --- Auto mode ---
if [[ "$AUTO_MODE" == true ]]; then
    info "Auto mode enabled — checking .env.template for API keys..."
    TMPL_ANTHROPIC_KEY=$(read_template_key "ANTHROPIC_API_KEY")

    if [[ -n "$TMPL_ANTHROPIC_KEY" ]]; then
        inject_key "ANTHROPIC_API_KEY" "$TMPL_ANTHROPIC_KEY"
        ok "Injected ANTHROPIC_API_KEY from .env.template"
    else
        warn "No valid ANTHROPIC_API_KEY found in .env.template — agent will need manual configuration"
    fi

    # Also try optional keys
    for OPTIONAL_KEY in BRAVE_API_KEY GITHUB_TOKEN; do
        TMPL_VAL=$(read_template_key "$OPTIONAL_KEY")
        if [[ -n "$TMPL_VAL" ]]; then
            inject_key "$OPTIONAL_KEY" "$TMPL_VAL"
            ok "Injected ${OPTIONAL_KEY} from .env.template"
        fi
    done

    launch_container

    if [[ -n "$TMPL_ANTHROPIC_KEY" ]]; then
        show_live_card
    else
        show_onboarding_card
    fi

# --- Interactive mode ---
else
    echo
    echo -e "${BOLD}🔑 API Key Setup${NC}"
    read -rp "$(echo -e "${CYAN}Would you like to provide your API keys now and skip the onboarding wizard? (y/n):${NC} ")" SETUP_KEYS

    if [[ "$SETUP_KEYS" =~ ^[Yy]$ ]]; then
        echo
        read -rp "$(echo -e "${CYAN}Enter your ANTHROPIC_API_KEY:${NC} ")" USER_ANTHROPIC_KEY

        if [[ -n "$USER_ANTHROPIC_KEY" ]]; then
            inject_key "ANTHROPIC_API_KEY" "$USER_ANTHROPIC_KEY"
            ok "ANTHROPIC_API_KEY configured"
        else
            warn "No key entered — you can set it later in ${AGENT_DIR}/.env"
        fi

        launch_container
        show_live_card
    else
        launch_container
        show_onboarding_card
    fi
fi
