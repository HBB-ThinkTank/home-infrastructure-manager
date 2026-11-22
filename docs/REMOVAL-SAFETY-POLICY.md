# Software relationship and removal safety policy (draft)

HIM is an inventory and maintenance tool for small home networks; it is **not** an autonomous system cleanup agent.

## Core rule

**Any detected or suspected manual invocation, or use by a different application than the original automatic installer intended, requires explicit user approval before uninstalling.**

Silent automatic removal could be considered only for components originally installed without direct user action by a known automated process, with positively verified provenance and sufficiently complete evidence that their *sole original purpose* has been superseded. This condition is difficult to establish and **cannot** be met simply because there are no observed process launches.

## Removal decision table

| Evidence | HIM action |
| --- | --- |
| Installed manually | Approval required |
| Install provenance unknown or reconstructed by guess | Approval required |
| Observed manual start | Approval required |
| Used by another program (even once) | Approval required |
| Other consumer merely suspected | Approval required |
| No evidence of execution (without comprehensive monitoring) | Approval required |
| Shared library, runtime, driver, critical or OS-managed component | Do not auto-remove; strong warning / restricted handling |
| HIM-recorded silent auto-install, solely intended for now-retired functionality, complete evidence of no independent consumers, explicit allowlist and rollback available | *Potentially* eligible in a future opt-in mode, never by default |
| Conflicting evidence or observation gaps | Approval required |

## Detection constraints

1. Scan results prove presence, **not** how or why an application was installed.
2. A single process snapshot does not capture every execution.
3. Process-start history requires explicitly configured OS audit/event collection and may include sensitive information.
4. Process parent-child relationships indicate direct invocation, not every indirect dependency (COM, dynamic libraries, IPC, shell associations, services).
5. User notes and explicit opt-out from automation override inferred decisions.

## Architectural implications

- Track installation provenance, dependencies, invocations, source/evidence, confidence, completeness and manual comments separately.
- Separate a recommendation engine from an update/removal executor.
- Removals require idempotency checks, preview, logging and a package-manager-aware reversibility plan.
- Do not implement any automatic uninstall path in the first HIM milestones.

References and mapping: [Inventory format comparison](INVENTORY-FORMAT-COMPARISON.md).
