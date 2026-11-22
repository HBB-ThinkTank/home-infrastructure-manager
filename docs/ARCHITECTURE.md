# Architecture (initial proposal)

HIM favors **modular components within a simple deployable system**. Do not introduce microservices solely for modularity.

## Logical components

- **Collectors:** read-only, operating-system-specific inventory gathering; usable standalone.
- **Schema:** versioned, documented JSON definitions with an explicit distinction between shared and OS-specific fields.
- **Coordinator:** optional remote execution, scheduling and orchestration.
- **History:** snapshot storage and comparison.
- **Maintenance adapters:** separately authorized, allowlisted package-manager operations.
- **Reporting:** text, JSON and eventually HTML/UI exports.

These are logical responsibilities, **not** a fixed package layout.

## Design boundaries

1. Collection and maintenance must be separate execution paths and privileges.
2. A failed category must be reportable without silently pretending that data is absent.
3. Every data item should retain host identity and collection time; provenance is useful where available.
4. Never store credentials in inventory exports.
5. Do not require a network connection or a database merely to run a local collector.
6. Prefer secure authenticated remote connections; never expose management endpoints to the internet by default.
7. User-provided context (e.g. planned NAS replacement) must be distinct from automatically observed facts.

## Prototype status

The July 2026 Windows Inventory Tool is an existing **prototype**, not yet the HIM implementation. Its integration, tests, output compatibility and security review remain to be done.
