# Windows Inventory Tool v1.1 → CycloneDX 1.7 / SPDX 3.0.1 field mapping

**Status:** Draft mapping based on the original, fully inspected `legacy/windows-inventory-tool/Get-WindowsInventory.ps1` (2026-07-29). Prepared 2026-11-22.

**Important validation boundary:** The historical `MININT-22BNPVK_2026-07-29_165653.zip` inventory archive was located in the conversation but its internal `Inventory.json` could **not** be read in this execution environment. Thus this is a comprehensive **source-code-derived field mapping**, not a claim of a verified field-by-field transformation of actual July JSON values. No valid CycloneDX or SPDX output has yet been generated or schema-validated. Do not label it an implemented converter.

## Semantics

- **Direct:** concept expressible by an appropriate standard object/field.
- **Property/annotation:** can carry information, but generic consumers may not understand it.
- **Loss if omitted:** would lose meaning if only native standard elements are exported.
- **HIM:** requires an internal field or separate storage.
- Mapping is *not* necessarily 1:1; an observed installed instance is different from a product or package description.
- `Null`, `Unknown`, `NotCollected`, `Unsupported` and `Absent` must be distinguishable.
- Keep the original raw observation along with normalized representations when privacy allows.

## Source → target matrix

| Legacy JSON path / exact fields | CycloneDX 1.7 | SPDX 3.0.1 | HIM / information-loss notes |
| --- | --- | --- | --- |
| `Metadata.SchemaVersion` | `specVersion` is **CycloneDX's** version, not the legacy version; property/metadata | `specVersion` likewise not legacy version | Preserve source schema version separately |
| `Metadata.CreatedAt` | `metadata.timestamp` direct, after conversion to RFC 3339/ISO 8601 | creation info date via relevant creation metadata | Convert legacy timestamp `yyyy-MM-dd HH:mm:ss zzz`, preserve timezone |
| `Metadata.ComputerName` | Device component name / metadata component | hardware element name if hardware profile used | Hostname changes; not stable identity |
| `Metadata.UserName` | Optional private property | Annotation/extension only | Sensitive; redact from public BOM by default |
| `Metadata.IsAdministrator` | Property | Annotation | Collection privilege/evidence completeness |
| `Metadata.PowerShellVersion` | tool/component version (if collector declared) | tool metadata / software package | Collector runtime vs installed tool distinguish |
| `Metadata.PortableRoot` | Property | Annotation | Local sensitive path; omit from shared exports |
| `Metadata.IncludeMicrosoftTasks, IncludeMicrosoftServices` | Property | Annotation | Crucial collection scope: omitted entries ≠ not installed |
| `InstalledPrograms[].Name, Version, Publisher` | `components[]` application/library fields, supplier/publisher depending on source semantics | Software Package/name/version/supplier metadata | Name normalization/unique instance ID required |
| `InstalledPrograms[].InstallDate` | Property/annotation | Annotation | Preserve observed installation date and provenance |
| `InstalledPrograms[].InstallLocation, InstallSource` | Properties; external refs only if semantically appropriate | Annotation / location metadata where applicable | Local paths, source is not necessarily package-manager proof |
| `InstalledPrograms[].UninstallString, QuietUninstall` | No suitable direct inventory field | No suitable standard uninstall semantics | Security-sensitive executable commands; store restricted, never execute blindly |
| `InstalledPrograms[].WindowsInstaller, SystemComponent, ReleaseType` | Properties | Annotations | OS/installer metadata, caution on removal |
| `InstalledPrograms[].Scope, Architecture, RegistryKey` | Properties (some component scope semantics differ) | Annotations/other metadata | Scope is user/machine, not dependency scope; registry key is observation locator |
| `AppxPackages[].Name, PackageFullName, Version, Publisher, Architecture` | Application/package components and properties | Package identity and annotations | Preserve full Windows package identity and observed architecture |
| `AppxPackages[].InstallLocation, IsFramework, NonRemovable, SignatureKind` | Properties | Annotations | NonRemovable must survive normalization |
| `PortablePrograms.Root, RootExists` | Properties | Annotations | Scanning coverage: root absent ≠ no portable apps |
| `PortablePrograms.Programs[].Name, ProductName, ProductVersion, CompanyName` | Component name/version/supplier (with provenance) | Software package metadata | Heuristic detection: product identity is not confirmed |
| `PortablePrograms.Programs[].Folder, Modified, ExecutableCount, PrimaryExecutable, FileDescription` | File components and properties | File elements + annotations | Executable selection is heuristic (largest EXE after filter); never treat as verified app entry point |
| `Services[].Name, DisplayName, State, StartMode, StartName` | Service object only when CycloneDX service semantics fit; properties otherwise | Annotation/extension | Windows service lifecycle/account is not equivalent to network/API service |
| `Services[].PathName, Executable, Company, Description, IsMicrosoft` | Property/linked component | Software/file element + annotations | A path suggests candidate owning app, not proven installed dependency |
| `StartupItems[].Name, Command, Scope, Type, Source` | Properties/annotations on component | Relationship/annotation | Command strings sensitive; preserve OS-specific item |
| `ScheduledTasks[].TaskName, TaskPath, State, Author, Description, Actions, Triggers, IsMicrosoft` | Properties/annotations | Annotation and maybe relations | Task scheduling and triggers have no accurate BOM-equivalent; redaction required |
| `Hardware.Computer.ComputerName, Manufacturer, Model, SystemType, TotalMemoryGB, LoggedOnUser` | Device component + properties | Hardware profile/entity if implemented, annotations | LoggedOnUser sensitive; TotalMemoryGB rounded |
| `Hardware.OperatingSystem.Caption, Version, BuildNumber, Architecture` | `operating-system` component, optional properties | Software Package + annotations | Keep OS installed instance and version |
| `Hardware.OperatingSystem.InstallDate, LastBootUpTime` | Properties | Annotations | Operational state, not immutable BOM property |
| `Hardware.BIOS.Manufacturer, Name, Version, ReleaseDate, SerialNumber` | Firmware component + properties | Firmware-related elements where profile supports; annotations | Serial number sensitive |
| `Hardware.Mainboard.Manufacturer, Product, Version, SerialNumber` | Device component + properties | Hardware profile/entity + annotations | Board is physical component; preserve real device relationship |
| `Hardware.Processors[].Name, Manufacturer, Cores, LogicalProcessors, MaxClockMHz` | Device component + properties | Hardware profile + annotations | Distinguish logical vs physical CPU; clock is max advertised |
| `Hardware.MemoryModules[].Manufacturer, PartNumber, CapacityGB, SpeedMHz, ConfiguredSpeedMHz, SerialNumber` | Device components + properties | Hardware profile + annotations | Differentiate configured vs rated speed; floating/rounded size |
| `Hardware.Graphics[].Name, DriverVersion, AdapterRAMGB, VideoProcessor` | Device + driver component; properties | Hardware/software model + annotation | VRAM Windows WMI may be inaccurate; mark evidence |
| `Hardware.PhysicalDisks[].FriendlyName, MediaType, BusType, HealthStatus, OperationalStatus, SizeGB, SerialNumber` | Device component + properties | Hardware element + annotations | Actual disk identity, health as timed observation; sensitive serial |
| `Hardware.Volumes[].DriveLetter, FileSystemLabel, FileSystem, HealthStatus, SizeGB, FreeGB` | Properties/extension | Annotations | No reliable physical disk→partition→volume link in legacy data; volume-specific model needed |
| `Network.Adapters[].Name, InterfaceDescription, Status, LinkSpeed, MacAddress, DriverInformation, Virtual` | Device component + properties | Hardware profile + annotations | MAC sensitive; link status/time-dependent |
| `Network.Profiles[].InterfaceAlias, Name, NetworkCategory, IPv4Connectivity, IPv6Connectivity` | Properties/extension | Annotation | Must join on host/interface identity; alias mutable |
| `Network.IPConfiguration[].InterfaceAlias, IPv4Address, IPv6Address, IPv4Gateway, DNSServers` | Properties/extension | Annotation | Potentially sensitive network topology; addresses are comma-concatenated strings in legacy |
| `DevelopmentTools[].Name, Found, Path, Version` | Software components where found; not-found scope is property/annotation | Software Package + annotation | A PATH lookup result is *not* an exhaustive installed/uninstalled verdict; Version may contain multiple lines |
| `Security.Antivirus[].DisplayName, ProductState, PathToSignedProductExe, PathToSignedReportingExe` | Component + properties/annotations | Package + annotations | ProductState opaque encoded value; security-sensitive paths |
| `Security.FirewallProfiles[].Name, Enabled, DefaultInboundAction, DefaultOutboundAction` | Properties or optional service | Annotation | Operational security state, not simple BOM |
| `Security.BitLocker[].MountPoint, VolumeStatus, ProtectionStatus, EncryptionPercentage, EncryptionMethod` | Properties | Annotation | Encrypted volume state; do not disclose publicly by default |

## Explicit field-level limitations in the legacy collector

1. `InstalledPrograms` is Registry-based, may have duplicates, missing versions or misleading `InstallDate`; `InstallSource` does *not* prove who initiated an installation.
2. `AppxPackages` is collected via `Get-AppxPackage`, scoped to the executing context; not an all-users/full machine package database.
3. `PortablePrograms` scans only immediate subfolders of a configurable root; its primary executable is a heuristic, and missing roots produce `RootExists=false`.
4. `Services` and `ScheduledTasks` exclude many Microsoft items by default. Missing entries may be filtered, not absent.
5. Physical disks and volumes are separate lists without robust relationship IDs; rounded GB fields do not preserve exact bytes.
6. `DevelopmentTools` checks 14 fixed CLI names via `PATH` and captures command output; cannot infer usage or installed ownership.
7. `Network.IPConfiguration` flattens multiple values into joined strings, losing precise typed arrays.
8. `Security` checks specific Windows providers and may omit data on errors.
9. `Metadata.ComputerName` is not a persistent host identifier; `RegistryKey`, paths, MACs and hardware serials require sensitive-data handling.
10. There are no observation timestamps per field, confidence/source types per relation, install lineage, explicit dependencies or durable manual comments.

## Three worked mappings (illustrative, not from the July inventory)

### Installed desktop program

Legacy observation:
```json
{"Name":"ExampleTool","Version":"2.3","Publisher":"Example Co","Scope":"Machine","Architecture":"64-bit or neutral","RegistryKey":"example-key"}
```

CycloneDX: a `components[]` item of type `application` with `name` and `version`; place scope, architecture and discovery key into namespaced properties or keep only in HIM. Do not promote publisher to manufacturer without verification.

SPDX: `software_Package` or relevant software element with name/version, plus annotations for OS registry discovery and installation scope. An observed program is an *installation*, not necessarily a distributable package.

### Disk / volume

Legacy: physical disk `SerialNumber`, `SizeGB` and separately volume `DriveLetter`, `FileSystem`, `FreeGB`.

CycloneDX: hardware `device` component plus vendor properties; volume as a distinct extension entity if needed. Existing data do **not** prove that volume D: belongs to any particular physical disk.

SPDX: hardware element if applicable, volume layout/health as extensions. Cross-identification still unavailable.

### Shared CLI dependency

Legacy `DevelopmentTools[].Found=true` for `ffmpeg` does not establish which application calls it. Both CycloneDX and SPDX can describe *declared* component relationships; neither can create an evidentially justified edge `video-processor invokes ffmpeg` from PATH presence alone. HIM requires manual confirmation, executable inspection or optional process evidence.

## Proposed architecture based on mapping

1. Retain normalized, typed **HIM inventory observations** as the source of truth, including source raw values and collector scope.
2. Keep persistent annotations, user decisions, planned state and relationships **separate from ephemeral scans**.
3. Export selected, suitable fields to **CycloneDX 1.7** and **SPDX 3.0.1**, documenting ignored or extension-only fields per export.
4. Support standards concurrently. Do not force every OS-operational object into a supply-chain BOM.
5. Preserve provenance, observation time and explicit distinctions between *absent*, *not collected*, *unavailable*, and *inferred*.
6. Do not generate uninstall eligibility from the mere absence of a usage relationship; see [Removal safety policy](REMOVAL-SAFETY-POLICY.md).

## Validation backlog

- [ ] Read the *actual* `Inventory.json` from `MININT-22BNPVK_2026-07-29_165653.zip` in a byte-accessible runtime.
- [ ] Enumerate every field's actual types and null/empty occurrence rates; compare to the source-code field list.
- [ ] Generate sanitized fixtures from real data with deterministic pseudonyms, no machine IDs/paths/network secrets.
- [ ] Prototype CycloneDX 1.7 JSON export and validate against the **official** `bom-1.7.schema.json`.
- [ ] Prototype SPDX 3.0.1 JSON-LD and validate using the official model/validation tooling.
- [ ] Produce machine-readable loss reports per export: `native`, `extension`, `HIM-only`, `redacted`, `uncollected`.
- [ ] Test round trips and record what cannot be recovered after standard export.

## Official references

- CycloneDX 1.7 JSON reference: https://cyclonedx.org/docs/1.7/json/
- CycloneDX 1.7 schema: https://github.com/CycloneDX/specification/blob/master/schema/bom-1.7.schema.json
- SPDX 3.0.1 relationship class: https://spdx.github.io/spdx-spec/v3.0.1/model/Core/Classes/Relationship/
- SPDX 3.0.1 software package: https://spdx.github.io/spdx-spec/v3.0.1/model/Software/Classes/Package/
- SPDX 3.0.1 relationship type: https://spdx.github.io/spdx-spec/v3.0.1/model/Core/Properties/relationshipType/
