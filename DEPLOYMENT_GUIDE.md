# A Professional Guide to Autonomous Agent Deployment

Running an autonomous AI agent is a high-stakes endeavor. An agent with access to a shell, a web browser, and local files is effectively a **"digital intern"** with infinite speed and no physical fatigue. To ensure this power remains a benefit rather than a liability, this project advocates for a **Double-Layered Sandbox** architecture.

---

## Table of Contents

- [I. The Why: Three Pillars of Isolation](#i-the-why-three-pillars-of-isolation)
  - [1. Defense in Depth (Hard Isolation)](#1-defense-in-depth-hard-isolation)
  - [2. The Network Laboratory](#2-the-network-laboratory)
  - [3. Environment Parity](#3-environment-parity)
- [II. Step-by-Step Environment Setup](#ii-step-by-step-environment-setup)
  - [Phase 1: Preparing the Windows Host (Hyper-V)](#phase-1-preparing-the-windows-host-hyper-v)
  - [Phase 2: Constructing the VM (Ubuntu)](#phase-2-constructing-the-vm-ubuntu)
  - [Phase 3: The Developer Bridge (VS Code SSH)](#phase-3-the-developer-bridge-vs-code-ssh)
  - [Phase 4: Birth (The Incubator)](#phase-4-birth-the-incubator)
- [III. The Governance of the Hive: Communication & Control](#iii-the-governance-of-the-hive-communication--control)
  - [1. Physical Layer: The Fleet Highway](#1-physical-layer-the-fleet-highway)
  - [2. Logical Layer: Authority & Discovery](#2-logical-layer-authority--discovery)
  - [3. The Onboarding Gateway: Guided vs. Automated](#3-the-onboarding-gateway-guided-vs-automated)
- [IV. Operational Guidelines](#iv-operational-guidelines)
- [Appendix: Agent Governance Checklist](#appendix-agent-governance-checklist)

---

## I. The Why: Three Pillars of Isolation

### 1. Defense in Depth (Hard Isolation)

Most users run Docker directly on their primary operating system; however, Docker shares the host's kernel. A **"container breakout"** could theoretically give an agent access to your primary OS files.

By placing Docker inside a **Hyper-V Virtual Machine**, we create a hardware-level barrier. If an agent executes a destructive command, it only impacts a disposable Linux environment, leaving your Windows host and personal data **untouched**.

### 2. The Network Laboratory

By using a VM, you gain control over the **Virtual Switch**. You can isolate your agents in a "private lab" where they can communicate with each other but are **blocked from accessing your local network** (like smart home devices or printers) unless you explicitly open a bridge.

### 3. Environment Parity

> *"It works on my machine"* is the enemy of collaboration.

By standardizing on **Ubuntu 24.04** inside Hyper-V, we ensure that every developer — whether on Windows, Mac, or Linux — is operating in an identical environment. This makes the `spawn_agent.sh` script universal.

---

## II. Step-by-Step Environment Setup

### Phase 1: Preparing the Windows Host (Hyper-V)

1. **Enable Hyper-V** — Open PowerShell as Administrator and run:

   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
   ```

   Restart your computer.

2. **Create a Virtual Switch** — In Hyper-V Manager, create a **New external virtual network switch** named `OpenClaw-Switch`.

### Phase 2: Constructing the VM (Ubuntu)

1. **Download Ubuntu** — Obtain the [Ubuntu 24.04 LTS](https://ubuntu.com/download/server) ISO.
2. **Create the VM** — Use **Generation 2**, assign **4096 MB RAM** (Static), and connect to `OpenClaw-Switch`.
3. **Installation** — During setup, you **MUST** select **"Install OpenSSH Server"**.

### Phase 3: The Developer Bridge (VS Code SSH)

1. **Get VM IP** — Inside Ubuntu, run:

   ```bash
   ip addr
   ```

2. **Connect** — In VS Code, use the **Remote - SSH** extension to connect:

   ```bash
   ssh your_username@192.168.1.50
   ```

### Pre-Installation Check

Before spawning your first agent, confirm your local OpenClaw image tag:

```bash
docker ps --format '{{.Image}}'
```

Ensure the output matches the image name in your `docker-compose.template.yml`. If you built OpenClaw locally, the image will typically be `openclaw:local` rather than a Docker Hub reference.

### Phase 4: Birth (The Incubator)

1. **Install Docker:**

   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh
   ```

2. **Clone & Spawn:**

   ```bash
   git clone https://github.com/mableclaw/dockered_openclaw_agent_incubator.git
   cd dockered_openclaw_agent_incubator
   chmod +x spawn_agent.sh
   ./spawn_agent.sh "Research-Lead" 18789
   ```

---

## III. The Governance of the Hive: Communication & Control

A single agent is a tool; a fleet is a workforce. As you move from one agent to many, managing how they interact is vital for **security** and **efficiency**.

### 1. Physical Layer: The Fleet Highway

All agents spawned by the Incubator automatically join a shared Docker network named **`openclaw-fleet`**. This provides **Internal DNS Resolution**:

- **Collaboration** — Agents can reach each other by name (e.g., `http://openclaw-Research-Lead:18789`).
- **Isolation** — To "silo" an agent, simply remove the `networks` block from its `docker-compose.yml`. It will then be physically unable to communicate with its peers.

### 2. Logical Layer: Authority & Discovery

Just because a "road" (network) exists doesn't mean an agent is authorized to drive on it. We use two logical controls to govern the hive:

- **Peer Discovery** — Agents only interact with peers whose URLs are explicitly defined in their individual `.env` files. If you don't provide the address, they won't "look" for it.
- **Gatekeeper Tokens** — Even on a shared network, communication is authenticated. Agent A cannot command Agent B unless it possesses Agent B's `OPENCLAW_GATEWAY_TOKEN`.

### 3. The Onboarding Gateway: Guided vs. Automated

The Incubator supports two deployment philosophies to balance automation with manual control:

- **The Automated Path** — When running the spawn script with pre-configured API keys (e.g., in the root `.env.template`), the agent is **"Born Ready"**. The script injects the generated `OPENCLAW_GATEWAY_TOKEN` and launches the agent instantly.
- **The Guided Path (TUI)** — If the user chooses to perform manual setup, the script launches the container and provides the command to enter the configuration wizard:

  ```bash
  docker exec -it openclaw-[AGENT_NAME] npx openclaw configure
  ```

  This opens the standard **OpenClaw Onboarding Wizard** for hand-crafted configuration of model, channels, skills, and more.

---

## IV. Operational Guidelines

- **Snapshots are your friend** — Take a Hyper-V **Checkpoint** before any major experimental runs.
- **Resource Monitoring** — Use `docker stats` inside the VM to ensure your agents aren't fighting for CPU/RAM.
- **Persistence** — All agent data lives in the `deployed_agents/` directory on the VM host. **Back up this folder** to preserve their long-term memory.
- **Port Ranges** — Ensure your chosen host port does not overlap with the Mother Agent's range (typically `18789-18790`). The auto-port feature starts new agents at `18791` and above to avoid conflicts.

---

## Appendix: Agent Governance Checklist

Before deploying a new networked agent, verify the following:

- [ ] **Network Boundary:** Is the agent joined to `openclaw-fleet`?
- [ ] **Identity Verification:** Has a unique `OPENCLAW_GATEWAY_TOKEN` been generated and confirmed?
- [ ] **Discovery Audit:** Does the `.env` only contain authorized peer URLs?
- [ ] **Persistence Path:** Is the `./workspace` correctly mapped to the host's `deployed_agents/` directory?
