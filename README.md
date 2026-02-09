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
./spawn_agent.sh my-agent 18800
```

The spawner will ask if you want to provide your API keys now. If you say **yes**, it injects them into the agent's `.env`, pulls the image, and launches the container — your agent is live at `http://localhost:18800` immediately.

If you say **no**, the container still launches but you'll need to complete onboarding via `docker attach openclaw-my-agent`.

### Pro Mode (--auto)

Pre-configure your keys once in `.env.template`, then spawn agents hands-free:

```bash
# 1. Fill in your API keys in the template
nano .env.template  # Set ANTHROPIC_API_KEY (and optionally BRAVE_API_KEY, GITHUB_TOKEN)

# 2. Spawn with --auto — no prompts, keys injected automatically
./spawn_agent.sh my-agent 18800 --auto
```

## Usage

```bash
# Spawn an agent (interactive mode — prompts for API keys)
./spawn_agent.sh <agent-name> <port>

# Spawn an agent (auto mode — injects keys from .env.template, no prompts)
./spawn_agent.sh <agent-name> <port> --auto

# Examples
./spawn_agent.sh research-bot 18801
./spawn_agent.sh code-reviewer 18802 --auto
./spawn_agent.sh personal-assistant 18803

# Show help
./spawn_agent.sh --help
```

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
# Spawn two agents
./spawn_agent.sh agent-alpha 18801
./spawn_agent.sh agent-beta 18802

# From inside agent-alpha, you can reach agent-beta at:
# http://openclaw-agent-beta:18789
```

## License

MIT
