# Inventory formats and dependency-model comparison

Status: research draft (2026-11-22). This is a **mapping and design assessment**, not an adopted HIM schema. Ratings describe how naturally a standard addresses a requirement, not proof that a collector can detect it.

## Legend

- **Native**: expressible using first-class concepts of the format.
- **Extension**: via general annotations, properties, or custom relationships, with possible interoperability loss.
- **Partial**: represents only part of the requirement or needs interpretation.
- **No**: no suitable native capability for HIM's purpose.
- **Collector**: a data-gathering tool, not a standard exchange schema.

## Requirements and standards matrix

| HIM requirement | Legacy Windows v1.1 | CycloneDX 1.7 | SPDX 3.0.1 | OCSF | SWID / ISO 19770-2 | osquery | Likely HIM-specific need |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Host and collection timestamp | Native, limited | Partial | Partial | Native (inventory event) | No | Collector | Persistent host IDs, source and scan status |
| OS, CPU, RAM, board, BIOS | Native | Partial / components | Partial (hardware profile) | Native / partial | No | Collector (platform-dependent) | Normalize units, identity, unknown vs unavailable |
| Disks, volumes, network adapters | Native | Extension / partial | Partial | Partial | No | Collector (platform-dependent) | Physical-to-logical disk relationships |
| Installed applications and versions | Native (Registry/AppX/portable) | Native | Native | Native | Native | Collector | Installed instance vs product identity |
| Portable and unmanaged executables | Heuristic | Native as components | Native as packages/files | Partial | Partial | Collector / custom checks | Detection methods and confidence |
| Package manager and installation source | Partial | Properties / pedigree partial | Relationships / annotations | Partial | Partial | Collector / platform metadata | Installer identity, intent, provenance history |
| Services, startup items, scheduled tasks | Native | Services / extension | Extension | Event / inventory partial | No | Collector | Platform-specific objects and relationships |
| Development CLI tools | Native, fixed list | Components | Packages/files | Software objects | Tags if available | Collector | Executable identity and multiple owners |
| Required and optional dependency edges | No | Native for dependency graph; optionality needs extension | Native (relationship types) | Partial | Partial | Collector for declared package deps | Dependency scope and evidence |
| Bundled, installed-by, invokes, replaces | No | Partial / properties | Relationship vocabulary / extension | Partial | Partial | Collector / logs, not full history | Typed edges, time, scope, direction |
| Shared component used by multiple apps | No | Graph possible | Graph possible | Partial | Partial | Collector can expose fragments | Cross-install identity and ownership |
| Last observed invocation / app use | No | Extension / evidence | Extension / annotations | Events suited | No | Event collection if enabled | Privacy-limited usage evidence with retention |
| User annotations, plans, decisions | No | Annotations / properties | Annotations | Extension | No | No | Durable commentary not overwritten by scans |
| Evidence, certainty, observed vs inferred | No | Evidence / compositions partial | Annotations / relationship metadata | Source/event metadata | Partial | Query provenance | Exact evidence type, temporal validity, negatives |
| Inventory snapshots and changes | One report per run | BOM snapshots; comparison external | Documents; comparison external | Events | Lifecycle tags limited | Scheduled queries/events | Timeline, diff, missing vs removed |
| Update policy, allowlist, audit | No | No (not a maintenance engine) | No | Activity events partial | No | No | Explicit operation policy, approvals, results |
| Deletion eligibility | No | No | No | No | No | No | Conservative HIM policy, never inferred merely from absence |

**Interpretation:** Use existing standards for exchange and reference semantics, not as a mandatory all-purpose internal database. Consider optional CycloneDX export for inventory, SPDX export for software/relationship data, and OCSF for events if an event pipeline is ever useful. SWID identifiers can help recognize packages where available. osquery may serve as an optional collector; it is not our canonical JSON schema.

## Legacy v1.1 field mapping

The script writes `Metadata` (`SchemaVersion='1.0'`, `CreatedAt`, `ComputerName`, `UserName`, `IsAdministrator`, `PowerShellVersion`, `PortableRoot`, include switches), `InstalledPrograms`, `AppxPackages`, `PortablePrograms`, `Services`, `StartupItems`, `ScheduledTasks`, `Hardware`, `Network`, `DevelopmentTools`, and `Security`.

Proposed treatment, subject to concrete sample-data validation:

| Existing section | Proposed HIM interpretation |
| --- | --- |
| Metadata | Collector run, host identity candidate, schema and timestamp. Do **not** use mutable computer name alone as durable identity. |
| InstalledPrograms, AppxPackages, PortablePrograms | Installed instances linked to normalized software product records, with detection source |
| DevelopmentTools | Executable/CLI-capability observations; may link to several products |
| Services, StartupItems, ScheduledTasks | OS-specific objects, edges to installed programs where defensible |
| Hardware, Network | Structured device/component records; keep vendor-specific raw values |
| Security | Observations with explicit sensitivity flags and optional collection |
| CSV, HTML and Summary exports | Derived views, never the canonical truth |

## Relationship graph: initial concepts (not a committed schema)

**Nodes:** host, installed software instance, product, executable, service, package, component, device, installation event, scan, user note.

**Edges:** `depends_on`, `optionally_uses`, `bundled_with`, `installed_by`, `invokes`, `shares_component`, `replaces`, `associated_with`, `runs_on`, `provided_by`.

Each edge needs at least: source/target IDs, relationship type and direction, evidence source, first/last confirmation or observation, scope (host vs global), status (known/unknown/inferred), and optional manually authored notes. The edge `associated_with` **must not imply** required dependency.

Distinct evidence states: declared by package manager; confirmed by documentation; directly observed execution; manually confirmed; inferred; unknown. Evidence may expire or conflict. **No observed invocation** is not equivalent to **not used**.

## Installation provenance and removals

An installed-product list is insufficient to prove a package was silently installed by another program, remains exclusive to that parent, or has never been invoked by a user. This is often impossible to determine retrospectively.

Future HIM removal rules (designed for *optional* functionality, not currently implemented):

1. **Default:** report removal candidates, do not uninstall.
2. **Potential unattended removal only:** HIM has positively recorded that this component was installed *automatically in the background* by a specific parent/workflow, with no direct user action; HIM controls or can verify the install provenance and knows the original intended purpose is superseded; explicit ownership is known; no other current dependent or consumer is known **with sufficient completeness**; no user/manual or unexpected invocations have occurred in a sufficiently observed period; no conflicting or uncertain evidence; dedicated allowlist and rollback/reinstallation plan; package manager confirms the safe removal set.
3. **Mandatory user approval:** any explicit manual start, invocation by another consumer, suspected external consumer, manual install, incomplete tracing, uncertainty about necessity, shared runtime, or missing provenance.
4. **Never claim absence of use solely from a periodic snapshot.** Do not automatically remove unknown legacy software.
5. **Do not delete data or packages solely because a program appears unused.** Extra safeguards for system components, drivers, shared runtimes, boot-critical software, and installed tools shared between hosts.
6. Record the proposed action, reasoning, evidence IDs, user choice, version, changes and verification result.

Note: full confidence in a program *never* being used by other applications is generally unattainable without persistent comprehensive monitoring. Therefore the real auto-removal set may be very small. **Conservative by design**.

## Lightweight collection approach

- **Baseline:** occasional inventory and package metadata; lowest overhead, no invocation histories.
- **Optional low-overhead enrichment:** read existing OS/package-manager install or audit logs; log presence and retention vary.
- **Explicit opt-in, time-limited observation:** Windows security process creation event 4688 (requires auditing enabled), or OS-specific Linux audit/eBPF/osquery event facilities. Process parentage and paths can sometimes prove invocations, but timestamps/log retention, short-lived processes, elevated permissions, and process ancestry limitations make completeness hard.
- Collecting command-line arguments may expose secrets; store the minimum necessary (ideally no arguments), set retention limits and explain privacy impact.
- Do not silently enable continuous tracing, modify audit settings, or require an always-running system-wide watcher.

## Research sources (official / primary)

- CycloneDX 1.7 reference: https://cyclonedx.org/docs/1.7/json/
- CycloneDX dependency use case: https://www.cyclonedx.org/use-cases/software-dependencies/
- SPDX 3.0.1 Relationship model: https://spdx.github.io/spdx-spec/v3.0.1/model/Core/Classes/Relationship/
- SPDX relationship vocabulary (3.0 family): https://spdx.github.io/spdx-spec/v3.0-dev/model/Core/Vocabularies/RelationshipType/
- OCSF classes / device inventory: https://lmodel.github.io/ocsf/schema/classes/
- SWID standard: https://www.iso.org/standard/65666.html
- osquery: https://github.com/osquery/osquery
- osquery Windows programs table: https://github.com/osquery/osquery/blob/master/specs/windows/programs.table
- Microsoft process creation auditing: https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/event-4688
- osquery process auditing: https://github.com/osquery/osquery/blob/master/docs/wiki/deployment/process-auditing.md

## Next research tasks

- Compare *sample* Windows Inventory v1.1 JSON field-by-field, not just top-level keys.
- Verify package manager dependency/provenance coverage on Windows (winget/Scoop/Cargo) and Linux (apt/dpkg).
- Prototype CycloneDX and SPDX exports with realistic fixture data.
- Quantify low-overhead execution provenance capture and distinguish positive evidence from incomplete monitoring.
- Write a formal HIM JSON schema only after testing the requirements and export mappings.
