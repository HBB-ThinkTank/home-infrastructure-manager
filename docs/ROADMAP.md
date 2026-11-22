# HIM Roadmap

This roadmap is a starting point, not a commitment to deadlines.

## Phase 1 — Inventory foundations

- Import and review the existing Windows Inventory Tool prototype as historical baseline.
- Define stable host identity, schema versioning, source provenance and snapshot timestamps.
- Introduce a Linux inventory collector with comparable core fields.
- Ensure inventory remains read-only, individually runnable and exportable to JSON.

## Phase 2 — Central coordination and history

- Configure known hosts explicitly and collect snapshots via secure remote connections.
- Store timestamped inventory snapshots (SQLite is a candidate).
- Compare snapshots and distinguish added, removed, changed and unavailable data.
- Export useful reports without requiring a web interface.

## Phase 3 — Controlled software maintenance

- Implement package-manager adapters rather than replacing package managers.
- Support per-host and per-package allowlists, dry runs and explicit approvals.
- Record command outcome, installed version before/after, logs and errors.
- Never assume an update succeeded solely from a command exit code.

## Phase 4 — Optional local UI

- Present hosts, inventories, differences and maintenance status.
- Keep headless CLI operation fully supported.
- Consider optional AI-assisted analysis only after reliable inventory and audit logs exist.

## Open design decisions

- JSON schema and cross-platform normalization boundaries.
- Whether remote operation should use SSH only or allow optional local agents.
- Coordinator runtime and UI approach.
- Update adapters and security privilege model.
