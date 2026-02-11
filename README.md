# 🐙 OpenClaw Agent Incubator

Spin up isolated OpenClaw AI agents in seconds. Each agent gets its own Docker container, workspace, config, and gateway token — completely self-contained and ready to pair.

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Docker](https://docs.docker.com/get-docker/) | 20.10+ | Container runtime |
| [Docker Compose](https://docs.docker.com/compose/install/) | v2+ | Service orchestration |
| `openssl` | any | Gateway token generation |
| `bash` | 4+ | Spawn script |

## Quickstart

```bash
# 1. Clone the repo
git clone https://github.com/mableclaw/dockered_openclaw_agent_incubator.git
cd dockered_openclaw_agent_incubator

# 2. Spawn your first agent (interactive — will ask for API keys)
./spawn_agent.sh my-agent
```

The spawner auto-selects the next available port (starting at **18790**) and generates a secure gateway token via `openssl rand -hex 32`, injecting it into the agent's `.env` automatically — no manual token management needed.

It will ask if you want to provide your API keys now. If you say **yes**, it injects them into the agent's `.env`, pulls the image, and launches the container — your agent is live immediately.

If you say **no**, the container still launches but you'll need to complete onboarding via `docker attach openclaw-my-agent`.

### Pro Mode (--auto)

Pre-configure your keys once in `.env.template`, then spawn agents hands-free:

```bash
# 1. Fill in your API keys in the template
nano .env.template  # Set ANTHROPIC_API_KEY (and optionally BRAVE_API_KEY, GITHUB_TOKEN)

# 2. Spawn with --auto — no prompts, keys injected automatically
./spawn_agent.sh my-agent --auto
```

## Usage

```bash
# Spawn an agent (auto port selection)
./spawn_agent.sh <agent-name>

# Spawn with an explicit port
./spawn_agent.sh <agent-name> <port>

# Auto mode (no prompts, keys from .env.template)
./spawn_agent.sh <agent-name> [port] --auto

# Examples
./spawn_agent.sh research-bot              # auto-picks next port (18790, 18791, ...)
./spawn_agent.sh code-reviewer 18795       # uses port 18795 explicitly
./spawn_agent.sh personal-assistant --auto # auto port + auto mode

# Show help
./spawn_agent.sh --help
```

### Port Selection

The **port argument is optional**. When omitted, the script scans all existing `deployed_agents/*/docker-compose.yml` files for host port mappings, finds the highest one, and increments by 1. If no agents exist yet, it defaults to **18790**.

When a port is provided, it's used as-is (direct port number, not an offset).

### Security — Auto-Generated Gateway Tokens

Each spawned agent receives a unique, secure gateway token generated via `openssl rand -hex 32`. This token is automatically injected into the agent's `.env` file as `OPENCLAW_GATEWAY_TOKEN` and `GATEWAY_TOKEN`. You don't need to create or manage tokens manually.

### Flags

| Flag | Description |
|------|-------------|
| `--auto` | Skip interactive prompts. Reads API keys from `.env.template` and injects any real (non-placeholder) values into the agent's `.env`. Pulls the image and launches the container automatically. |
| `--help` | Show usage information |

Each spawn creates a self-contained directory under `deployed_agents/`:

```
deployed_agents/my-agent/
├── docker-compose.yml    # Ready-to-run compose file
├── .env                  # Agent-specific environment (copied from template)
├── workspace/            # Agent's working directory
└── config/               # OpenClaw config (gateway token, etc.)
```

## Folder Structure

```
dockered_openclaw_agent_incubator/
├── README.md                      # You are here
├── .env.template                  # Environment variable blueprint
├── docker-compose.template.yml    # Compose template with placeholders
├── Dockerfile.custom              # Agent-specific dependencies (gog, himalaya, etc.)
├── spawn_agent.sh                 # Factory script — creates new agents
├── deployed_agents/               # All spawned agents live here
│   └── .gitkeep
└── .gitignore
```

## Onboarding Flow

When you spawn an agent, one of three things happens:

1. **Interactive YES** — You enter your API key at the prompt. The spawner writes it to `.env`, pulls the image, and starts the container. Agent is live immediately.
2. **Interactive NO** — Container launches but needs onboarding. Run `docker attach openclaw-<name>` to complete setup via the TUI.
3. **`--auto` mode** — Keys are read from `.env.template` automatically. If a valid `ANTHROPIC_API_KEY` is found, the agent launches fully configured. If not, it launches but needs manual onboarding.

## Custom Dependencies (Dockerfile.custom)

If your agent needs tools beyond the base OpenClaw image (Python packages, CLI tools, system libraries), create or edit `Dockerfile.custom` in the repo root.

When `spawn_agent.sh` detects this file, it **automatically builds a custom image** instead of pulling the stock one. Your dependencies are baked in — they survive restarts, rebuilds, and resets.

A ready-to-use `Dockerfile.custom` is included with **gog** (Gmail/Drive CLI) and **himalaya** (email client) pre-configured. Add your own dependencies at the bottom:

```dockerfile
# Example: add ffmpeg and a Python ML library
USER root
RUN apt-get update && apt-get install -y ffmpeg
USER node
RUN pip3 install --user --break-system-packages scikit-learn
```

### How It Works

1. `spawn_agent.sh` checks for `Dockerfile.custom` in the repo root
2. If found, builds `openclaw-custom:<agent-name>` using the base image as a layer
3. Updates the agent's `docker-compose.yml` to use the custom image
4. If not found, falls back to pulling `openclaw:local` as usual

### Rebuilding After Changes

If you modify `Dockerfile.custom` after spawning an agent, rebuild manually:

```bash
docker build -f Dockerfile.custom -t openclaw-custom:<agent-name> .
cd deployed_agents/<agent-name> && docker compose up -d --force-recreate
```

## Storage Persistence: Luggage vs Wallpaper

Understanding what survives a container reset is critical:

### 🧳 Luggage (Persistent — Survives Resets)

These directories are **mounted volumes** — they live on the host filesystem and persist across container restarts, rebuilds, and resets:

| Path (inside container) | Host location | Contains |
|---|---|---|
| `/app/workspace` | `deployed_agents/<name>/workspace/` | Your files, code, memory, projects |
| `/root/.openclaw` | `deployed_agents/<name>/config/` | OpenClaw config, gateway token, sessions |

**Rule of thumb:** If it's in `workspace/` or `config/`, it's safe. ✅

### 🖼️ Wallpaper (Temporary — Lost on Reset)

Everything else inside the container is **ephemeral** — it's part of the Docker image layer and gets wiped when the container is recreated:

| What | Example | Solution |
|---|---|---|
| `pip install` packages | `pandas`, `numpy` | Add to `Dockerfile.custom` |
| Downloaded binaries | `~/.local/bin/gog` | Add to `Dockerfile.custom` |
| apt-installed tools | `ffmpeg`, `jq` | Add to `Dockerfile.custom` |
| `/tmp` files | temp downloads | Move to workspace if needed |
| System config changes | `/etc/` modifications | Add to `Dockerfile.custom` |

**Rule of thumb:** If you installed it at runtime, it's wallpaper. Bake it into `Dockerfile.custom` to make it luggage. 🧳

## Managing Agents

```bash
# Start an agent
cd deployed_agents/my-agent && docker compose up -d

# View logs
docker compose logs -f

# Stop an agent
docker compose down

# Restart
docker compose restart

# Remove an agent entirely
cd ../.. && rm -rf deployed_agents/my-agent
```

## Environment Variables

See `.env.template` for the full list. At minimum you need:

- **`ANTHROPIC_API_KEY`** — Your Anthropic API key (required)
- **`OPENCLAW_MODEL`** — Model to use (defaults to `anthropic/claude-sonnet-4-20250514`)

Optional keys unlock extra capabilities (web search, GitHub integration, etc.).

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Port already in use | Pick a different port or check `lsof -i :<port>` |
| Agent directory already exists | Choose a different name or remove the existing one |
| Container won't start | Check `docker compose logs` in the agent directory |
| Permission denied on spawn script | Run `chmod +x spawn_agent.sh` |
| Missing API key errors | Ensure `.env` has your `ANTHROPIC_API_KEY` set |
| Docker not running | Start Docker Desktop or `sudo systemctl start docker` |

## Inter-Agent Communication / DNS Resolution

All agents spawned by this incubator automatically join a shared Docker network called `openclaw-fleet`. This enables direct container-to-container communication using DNS hostnames.

### How It Works

- The `openclaw-fleet` network is created automatically by `spawn_agent.sh` if it doesn't already exist
- Each agent's container name follows the pattern `openclaw-<agent-name>`
- Containers on the same Docker network can resolve each other by container name

### Reaching Other Agents

From inside any agent container, you can reach another agent using its container name as the hostname:

```
http://openclaw-research-bot:18789
http://openclaw-code-reviewer:18789
```

> **Note:** Use the internal port `18789` (not the host-mapped port) when communicating between containers on the fleet network.

### Example

```bash
# Spawn two agents (ports auto-assigned: 18790, 18791)
./spawn_agent.sh agent-alpha
./spawn_agent.sh agent-beta

# From inside agent-alpha, you can reach agent-beta at:
# http://openclaw-agent-beta:18789
```

## License

MIT
