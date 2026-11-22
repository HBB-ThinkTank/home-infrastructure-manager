# Home Infrastructure Manager (HIM)

A lightweight, modular infrastructure inventory and maintenance tool for **small home networks**.

> **Status:** Early planning / repository bootstrap. No functional HIM release exists yet.

## Goals

- Collect comparable Windows and Linux hardware, software, service and network inventories.
- Keep machine-readable, timestamped snapshots and show changes over time.
- Optionally coordinate inventories remotely over secure authenticated connections.
- Manage a small explicit allowlist of low-risk software updates, with audit logs and version verification.
- Stay local-first, open-source and useful without cloud or AI services.

## Design principles

1. **Simplicity First:** avoid complexity not justified by home-network use.
2. **Safety First:** inventory is read-only; maintenance requires separate authorization.
3. **Open by Design:** open formats, no required cloud account, freely licensed source.
4. **Modularity First:** independent, replaceable components when they serve a real purpose; modularity is not an end in itself.

## Development approach

Start by preserving and reviewing the July 2026 portable PowerShell Windows Inventory Tool as the historical prototype. Next, define a versioned common data model and a Linux collector. Central coordination, history, approved updates and an optional local UI follow in stages.

Python is the current candidate for a coordinator, but the architecture and implementation details are not yet finalized.

See [Roadmap](docs/ROADMAP.md), [Architecture](docs/ARCHITECTURE.md), [Inventory format comparison](docs/INVENTORY-FORMAT-COMPARISON.md), [Removal safety policy](docs/REMOVAL-SAFETY-POLICY.md) and [Contributing](CONTRIBUTING.md).

## Privacy and security

Inventory reports may contain serial numbers, device names, usernames, software lists, paths and IP addresses. **Do not commit real machine inventories or secrets to this public repository.** Remote access must be authenticated and encrypted. Updates must be expressly allowlisted; broad automatic upgrades are out of scope for the initial release.

## License

Dual-licensed under the **MIT License OR Apache License, Version 2.0**, at your option.

`SPDX-License-Identifier: MIT OR Apache-2.0`

See [LICENSE-MIT](LICENSE-MIT) and [LICENSE-APACHE](LICENSE-APACHE).
