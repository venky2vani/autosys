# apm-demo

Fresh project set up with [APM (Agent Package Manager)](https://github.com/microsoft/apm).

## Setup
```bash
pip install apm-cli      # or: pipx install apm-cli
apm install              # deploys .apm/ primitives + dependencies to Claude and Copilot
```

## Layout
- `apm.yml` – manifest (targets: claude, copilot)
- `.apm/instructions/` – local instruction primitives (source of truth)
- `.claude/rules/`, `.github/instructions/` – generated per-agent output
- `apm.lock.yaml` – resolved state (commit it)
- `apm_modules/` – downloaded packages (gitignored)

## Add a dependency
```bash
apm install <owner>/<repo>
```
