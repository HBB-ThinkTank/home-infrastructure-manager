# Original prototype provenance

Source: user-provided `windows-inventory-tool.zip`, containing three files dated 2026-07-29.

This directory is reserved for the **unchanged Windows Inventory Tool v1.1** prototype. Treat it as a historical baseline, not as the new HIM implementation.

Original PowerShell script:
- `Get-WindowsInventory.ps1`
- Size: 26,011 bytes
- SHA-256: `71ce5d1239781d3568d7e0d85c8d4241124072fcea93cdeb14b67eb54ab501cc`

Original launcher: `Inventur starten.cmd` (238 bytes).
Original README: `README.md` (2,015 bytes).

**Import status:** The original README and launcher have been imported. The executable PowerShell source file has **not yet been imported**. Do not treat this directory as runnable until the file is present and its hash matches.

The original tool writes reports containing machine and network details. Never commit generated inventory output to the public repository.

## Pending

Copy `Get-WindowsInventory.ps1` from the original ZIP into this directory without changes and verify the SHA-256 hash.
