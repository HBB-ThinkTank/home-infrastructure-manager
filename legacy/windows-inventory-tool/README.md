# Windows Inventory Tool

Ein portables PowerShell-Skript für die Inventur mehrerer Windows-PCs.

## Portable Programme

Standardmäßig wird dieser Ordner erfasst:

```text
C:\Program Manual Files
```

Jeder direkte Unterordner gilt als ein portables Programm. Das Skript sucht darin nach EXE-Dateien und liest, soweit vorhanden, Produktname, Version und Hersteller aus.

## Aufruf

PowerShell 7 als Administrator öffnen und im Skriptordner ausführen:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Get-WindowsInventory.ps1 -OpenReport
```

Alternativ genügt ein Doppelklick auf `Inventur starten.cmd`.

Die Ergebnisse landen unter:

```text
Computer Inventories\<COMPUTERNAME>\<DATUM_UHRZEIT>
```

## Enthaltene Ausgaben

- `Inventory.html` – gut lesbarer Bericht
- `Inventory.json` – vollständige maschinenlesbare Inventur
- `Summary.txt` – Kurzübersicht
- `CSV\*.csv` – Tabellen für Excel oder andere Tabellenprogramme

## Vollständige Microsoft-Dienste und -Aufgaben

Standardmäßig bleiben Microsoft-Dienste und Microsoft-Aufgaben aus Übersichtsgründen weitgehend ausgeblendet.

```powershell
.\Get-WindowsInventory.ps1 `
    -IncludeMicrosoftServices `
    -IncludeMicrosoftTasks `
    -OpenReport
```

## Anderer Ordner für portable Programme

```powershell
.\Get-WindowsInventory.ps1 -PortableRoot "D:\Portable" -OpenReport
```

Der feste Standard bleibt `C:\Program Manual Files`.

## Verwendung auf mehreren PCs

Den gesamten Ordner auf Haupt-PC, Backup-PC und Laptop kopieren. Die Ausgaben werden durch den Computernamen getrennt.

Die erste Version arbeitet ausschließlich lesend. Ein späterer Vergleich zweier JSON-Inventuren ist bereits durch die strukturierte Ausgabe vorbereitet.


## Änderung in Version 1.1

- Fehlende optionale Registry-Eigenschaften wie `InstallDate` führen nicht mehr zum Abbruch.
- Berichte werden nicht mehr im Programmordner gespeichert, sondern unter `Dokumente\Computer Inventories`.
- Jeder PC erhält dort einen eigenen Unterordner.
