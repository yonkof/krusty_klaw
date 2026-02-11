# Contributing to Krusty Klaw - Containerized OpenClaw Agents Generator

Thank you for your interest in contributing to the Containerized OpenClaw Agents Generator ecosystem! 🐙 Whether it's a bug fix, a new feature, or improved documentation — every contribution helps make agent deployment better for everyone.

## Bug Reports

Found a bug? Please [open an issue](https://github.com/yonkof/krusty_klaw/issues/new) and include:

- **Ubuntu version** (`lsb_release -a`)
- **Docker version** (`docker --version` and `docker compose version`)
- **Docker logs** (`docker compose logs` from the agent directory)
- **Steps to reproduce** — what you did, what you expected, what happened instead
- **Environment** — host OS, VM setup if applicable, any relevant config

The more detail you provide, the faster we can help.

## Feature Requests

Have an idea? Great — please **open an issue first** before writing code. This lets us:

- Discuss the approach and scope
- Avoid duplicate work
- Make sure it aligns with the project's direction

Label your issue with `enhancement` and describe the use case, not just the solution.

## Development Workflow

We follow a standard **Fork → Feature Branch → Pull Request** workflow:

1. **Fork** the repository to your GitHub account
2. **Clone** your fork locally
3. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/my-awesome-feature
   ```
4. **Make your changes** — keep commits focused and descriptive
5. **Test** your changes (spawn an agent, verify it works end-to-end)
6. **Push** your branch and open a **Pull Request** against `main`

### PR Guidelines

- Write a clear description of what your PR does and why
- Reference any related issues (`Fixes #12`, `Closes #7`)
- Keep PRs focused — one feature or fix per PR
- Be open to feedback during review

## Code Standards

### Bash Scripts

All bash scripts in this project should follow these conventions:

- **Always start with:**
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  ```
- Use meaningful variable names (uppercase for constants, lowercase for locals)
- Quote all variable expansions (`"$VAR"`, not `$VAR`)
- Add comments for non-obvious logic
- Use functions for reusable blocks
- Test edge cases (missing args, invalid input, port conflicts)

### Docker / Compose

- Use named networks (not default bridge)
- Keep compose files minimal and readable
- Don't hardcode secrets — use `.env` files and templates

### Documentation

- Update the README if your change affects usage
- Use clear, concise language
- Include examples where helpful

## Code of Conduct

Be respectful, constructive, and collaborative. We're all here to build something useful.

## Questions?

Not sure where to start? Open an issue tagged `question` and we'll point you in the right direction.

---

Thanks for helping make the Krusty Klaw better! 🦞
