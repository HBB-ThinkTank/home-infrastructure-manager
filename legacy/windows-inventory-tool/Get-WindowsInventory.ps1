<#
.SYNOPSIS
    Erstellt ein lesendes Inventar eines Windows-PCs.

.DESCRIPTION
    Erfasst installierte Programme, AppX-Pakete, portable Programme,
    Dienste, Autostarts, geplante Aufgaben, Hardware, Netzwerk,
    Entwicklungswerkzeuge und grundlegende Sicherheitsinformationen.

    Standardordner für portable Programme:
        C:\Program Manual Files

    Das Skript verändert nichts am System.
#>

[CmdletBinding()]
param(
    [string]$OutputRoot = (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Computer Inventories"),
    [string]$PortableRoot = "C:\Program Manual Files",
    [switch]$IncludeMicrosoftTasks,
    [switch]$IncludeMicrosoftServices,
    [switch]$OpenReport
)

# Registry- und CIM-Objekte besitzen je nach Programm bzw. Windows-Version
# nicht immer dieselben optionalen Eigenschaften. StrictMode 1.0 schützt
# weiterhin vor nicht initialisierten Variablen, erlaubt aber fehlende
# optionale Eigenschaften als $null.
Set-StrictMode -Version 1.0
$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-SafeValue {
    param([scriptblock]$ScriptBlock, $Fallback = $null)
    try { & $ScriptBlock } catch { $Fallback }
}

function Convert-ToIsoDate([AllowNull()][string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    if ($Value -match '^\d{8}$') {
        try {
            return ([datetime]::ParseExact($Value, 'yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture)).ToString('yyyy-MM-dd')
        } catch { return $Value }
    }
    return $Value
}

function Get-RegistryInstalledApps {
    $locations = @(
        @{ Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope='Machine'; Architecture='64-bit or neutral' },
        @{ Path='HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope='Machine'; Architecture='32-bit' },
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope='CurrentUser'; Architecture='64-bit or neutral' },
        @{ Path='HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope='CurrentUser'; Architecture='32-bit' }
    )

    $items = foreach ($location in $locations) {
        Get-ItemProperty $location.Path -ErrorAction SilentlyContinue |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.DisplayName) } |
            ForEach-Object {
                [pscustomobject]@{
                    Name             = $_.DisplayName
                    Version          = $_.DisplayVersion
                    Publisher        = $_.Publisher
                    InstallDate      = Convert-ToIsoDate $_.InstallDate
                    InstallLocation  = $_.InstallLocation
                    InstallSource    = $_.InstallSource
                    UninstallString  = $_.UninstallString
                    QuietUninstall   = $_.QuietUninstallString
                    WindowsInstaller = [bool]$_.WindowsInstaller
                    SystemComponent  = [bool]$_.SystemComponent
                    ReleaseType      = $_.ReleaseType
                    Scope            = $location.Scope
                    Architecture     = $location.Architecture
                    RegistryKey      = $_.PSChildName
                }
            }
    }

    $items | Sort-Object Name, Version, Scope, Architecture -Unique
}

function Get-AppxInventory {
    if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) { return @() }
    Get-AppxPackage -ErrorAction SilentlyContinue |
        Sort-Object Name |
        ForEach-Object {
            [pscustomobject]@{
                Name            = $_.Name
                PackageFullName = $_.PackageFullName
                Version         = $_.Version.ToString()
                Publisher       = $_.Publisher
                Architecture    = $_.Architecture.ToString()
                InstallLocation = $_.InstallLocation
                IsFramework     = $_.IsFramework
                NonRemovable    = $_.NonRemovable
                SignatureKind   = $_.SignatureKind.ToString()
            }
        }
}

function Get-PortableInventory([string]$Root) {
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return [pscustomobject]@{ RootExists=$false; Root=$Root; Programs=@() }
    }

    $programs = foreach ($directory in Get-ChildItem -LiteralPath $Root -Directory -Force -ErrorAction SilentlyContinue) {
        $executables = @(Get-ChildItem -LiteralPath $directory.FullName -Recurse -File -Filter '*.exe' -ErrorAction SilentlyContinue)
        $primaryExe = $executables |
            Where-Object { $_.Name -notmatch '(?i)(unins|uninstall|setup|install|update|crash|report|helper|service|daemon)' } |
            Sort-Object Length -Descending |
            Select-Object -First 1
        if (-not $primaryExe) { $primaryExe = $executables | Sort-Object Length -Descending | Select-Object -First 1 }
        $versionInfo = if ($primaryExe) { $primaryExe.VersionInfo } else { $null }

        [pscustomobject]@{
            Name              = $directory.Name
            Folder            = $directory.FullName
            Modified          = $directory.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
            ExecutableCount   = $executables.Count
            PrimaryExecutable = $primaryExe.FullName
            ProductName       = $versionInfo.ProductName
            ProductVersion    = $versionInfo.ProductVersion
            FileDescription   = $versionInfo.FileDescription
            CompanyName       = $versionInfo.CompanyName
        }
    }

    [pscustomobject]@{ RootExists=$true; Root=$Root; Programs=@($programs | Sort-Object Name) }
}

function Get-ServiceInventory([switch]$IncludeMicrosoft) {
    $services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | ForEach-Object {
        $exePath = $null
        if ($_.PathName -match '^\s*"([^"]+)"') { $exePath = $Matches[1] }
        elseif ($_.PathName -match '^\s*([^\s]+\.exe)') { $exePath = $Matches[1] }

        $company = if ($exePath -and (Test-Path -LiteralPath $exePath -PathType Leaf)) {
            Get-SafeValue { (Get-Item -LiteralPath $exePath).VersionInfo.CompanyName }
        }

        $isMicrosoft = ($company -match '(?i)Microsoft') -or
                       ($exePath -like "$env:SystemRoot\System32\*") -or
                       ($exePath -like "$env:SystemRoot\SysWOW64\*")

        [pscustomobject]@{
            Name        = $_.Name
            DisplayName = $_.DisplayName
            State       = $_.State
            StartMode   = $_.StartMode
            StartName   = $_.StartName
            PathName    = $_.PathName
            Executable  = $exePath
            Company     = $company
            Description = $_.Description
            IsMicrosoft = $isMicrosoft
        }
    }

    if ($IncludeMicrosoft) { return $services | Sort-Object DisplayName }
    $services | Where-Object { -not $_.IsMicrosoft } | Sort-Object DisplayName
}

function Get-StartupInventory {
    $items = @()
    $locations = @(
        @{ Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Scope='Machine'; Type='Run' },
        @{ Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Scope='Machine'; Type='RunOnce' },
        @{ Path='HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Scope='Machine32'; Type='Run' },
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Scope='CurrentUser'; Type='Run' },
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Scope='CurrentUser'; Type='RunOnce' }
    )

    foreach ($location in $locations) {
        if (-not (Test-Path $location.Path)) { continue }
        $properties = Get-ItemProperty $location.Path
        foreach ($property in $properties.PSObject.Properties) {
            if ($property.Name -match '^PS(Path|ParentPath|ChildName|Drive|Provider)$') { continue }
            $items += [pscustomobject]@{
                Name=$property.Name; Command=[string]$property.Value; Scope=$location.Scope; Type=$location.Type; Source=$location.Path
            }
        }
    }

    $folders = @(
        @{ Path=[Environment]::GetFolderPath('Startup'); Scope='CurrentUser' },
        @{ Path=[Environment]::GetFolderPath('CommonStartup'); Scope='AllUsers' }
    )
    foreach ($folder in $folders) {
        if (-not $folder.Path -or -not (Test-Path $folder.Path)) { continue }
        $items += Get-ChildItem -LiteralPath $folder.Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{ Name=$_.Name; Command=$_.FullName; Scope=$folder.Scope; Type='StartupFolder'; Source=$folder.Path }
        }
    }

    $items | Sort-Object Scope, Name
}

function Get-ScheduledTaskInventory([switch]$IncludeMicrosoft) {
    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) { return @() }

    $tasks = foreach ($task in Get-ScheduledTask -ErrorAction SilentlyContinue) {
        $actions = @($task.Actions | ForEach-Object {
            if ($_.Execute) { ($_.Execute + ' ' + $_.Arguments).Trim() }
            elseif ($_.ClassId) { "COM Handler: $($_.ClassId)" }
            else { $_.ToString() }
        })
        $triggers = @($task.Triggers | ForEach-Object {
            $type = $_.CimClass.CimClassName -replace '^MSFT_Task','' -replace 'Trigger$',''
            if ($_.StartBoundary) { "$type ($($_.StartBoundary))" } else { $type }
        })

        [pscustomobject]@{
            TaskName=$task.TaskName; TaskPath=$task.TaskPath; State=$task.State.ToString(); Author=$task.Author
            Description=$task.Description; Actions=($actions -join ' | '); Triggers=($triggers -join ' | ')
            IsMicrosoft=($task.TaskPath -like '\Microsoft\*')
        }
    }

    if ($IncludeMicrosoft) { return $tasks | Sort-Object TaskPath, TaskName }
    $tasks | Where-Object { -not $_.IsMicrosoft } | Sort-Object TaskPath, TaskName
}

function Get-HardwareInventory {
    $computer = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $bios = Get-CimInstance Win32_BIOS
    $board = Get-CimInstance Win32_BaseBoard | Select-Object -First 1

    [pscustomobject]@{
        Computer = [pscustomobject]@{
            ComputerName=$env:COMPUTERNAME; Manufacturer=$computer.Manufacturer; Model=$computer.Model
            SystemType=$computer.SystemType; TotalMemoryGB=[math]::Round($computer.TotalPhysicalMemory/1GB,2)
            LoggedOnUser=$computer.UserName
        }
        OperatingSystem = [pscustomobject]@{
            Caption=$os.Caption; Version=$os.Version; BuildNumber=$os.BuildNumber; Architecture=$os.OSArchitecture
            InstallDate=$os.InstallDate.ToString('yyyy-MM-dd HH:mm:ss'); LastBootUpTime=$os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')
        }
        BIOS = [pscustomobject]@{
            Manufacturer=$bios.Manufacturer; Name=$bios.Name; Version=$bios.SMBIOSBIOSVersion
            ReleaseDate=if($bios.ReleaseDate){$bios.ReleaseDate.ToString('yyyy-MM-dd')}else{$null}; SerialNumber=$bios.SerialNumber
        }
        Mainboard = [pscustomobject]@{
            Manufacturer=$board.Manufacturer; Product=$board.Product; Version=$board.Version; SerialNumber=$board.SerialNumber
        }
        Processors = @(Get-CimInstance Win32_Processor | ForEach-Object {
            [pscustomobject]@{ Name=$_.Name.Trim(); Manufacturer=$_.Manufacturer; Cores=$_.NumberOfCores; LogicalProcessors=$_.NumberOfLogicalProcessors; MaxClockMHz=$_.MaxClockSpeed }
        })
        MemoryModules = @(Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
            [pscustomobject]@{ Manufacturer=$_.Manufacturer; PartNumber=$_.PartNumber.Trim(); CapacityGB=[math]::Round($_.Capacity/1GB,2); SpeedMHz=$_.Speed; ConfiguredSpeedMHz=$_.ConfiguredClockSpeed; SerialNumber=$_.SerialNumber }
        })
        Graphics = @(Get-CimInstance Win32_VideoController | ForEach-Object {
            [pscustomobject]@{ Name=$_.Name; DriverVersion=$_.DriverVersion; AdapterRAMGB=if($_.AdapterRAM){[math]::Round($_.AdapterRAM/1GB,2)}else{$null}; VideoProcessor=$_.VideoProcessor }
        })
        PhysicalDisks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{ FriendlyName=$_.FriendlyName; MediaType=$_.MediaType.ToString(); BusType=$_.BusType.ToString(); HealthStatus=$_.HealthStatus.ToString(); OperationalStatus=($_.OperationalStatus -join ', '); SizeGB=[math]::Round($_.Size/1GB,2); SerialNumber=$_.SerialNumber }
        })
        Volumes = @(Get-Volume -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{ DriveLetter=$_.DriveLetter; FileSystemLabel=$_.FileSystemLabel; FileSystem=$_.FileSystem; HealthStatus=$_.HealthStatus.ToString(); SizeGB=if($_.Size){[math]::Round($_.Size/1GB,2)}else{$null}; FreeGB=if($_.SizeRemaining){[math]::Round($_.SizeRemaining/1GB,2)}else{$null} }
        })
    }
}

function Get-NetworkInventory {
    [pscustomobject]@{
        Adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{ Name=$_.Name; InterfaceDescription=$_.InterfaceDescription; Status=$_.Status.ToString(); LinkSpeed=$_.LinkSpeed; MacAddress=$_.MacAddress; DriverInformation=$_.DriverInformation; Virtual=$_.Virtual }
        })
        Profiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{ InterfaceAlias=$_.InterfaceAlias; Name=$_.Name; NetworkCategory=$_.NetworkCategory.ToString(); IPv4Connectivity=$_.IPv4Connectivity.ToString(); IPv6Connectivity=$_.IPv6Connectivity.ToString() }
        })
        IPConfiguration = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{ InterfaceAlias=$_.InterfaceAlias; IPv4Address=($_.IPv4Address.IPAddress -join ', '); IPv6Address=($_.IPv6Address.IPAddress -join ', '); IPv4Gateway=($_.IPv4DefaultGateway.NextHop -join ', '); DNSServers=($_.DNSServer.ServerAddresses -join ', ') }
        })
    }
}

function Invoke-VersionCommand([string]$Name,[string]$Command,[string[]]$Arguments=@('--version')) {
    $resolved = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $resolved) { return [pscustomobject]@{ Name=$Name; Found=$false; Path=$null; Version=$null } }
    $versionText = Get-SafeValue { (& $resolved.Source @Arguments 2>&1 | Select-Object -First 3) -join ' ' }
    [pscustomobject]@{ Name=$Name; Found=$true; Path=$resolved.Source; Version=$versionText }
}

function Get-DevelopmentToolsInventory {
    $tools = @(
        @{Name='PowerShell';Command='pwsh';Arguments=@('--version')},
        @{Name='Windows PowerShell';Command='powershell';Arguments=@('-NoProfile','-Command','$PSVersionTable.PSVersion.ToString()')},
        @{Name='Python';Command='python';Arguments=@('--version')},
        @{Name='Python Launcher';Command='py';Arguments=@('--version')},
        @{Name='Git';Command='git';Arguments=@('--version')},
        @{Name='Rust';Command='rustc';Arguments=@('--version')},
        @{Name='Cargo';Command='cargo';Arguments=@('--version')},
        @{Name='FFmpeg';Command='ffmpeg';Arguments=@('-version')},
        @{Name='ExifTool';Command='exiftool';Arguments=@('-ver')},
        @{Name='ImageMagick';Command='magick';Arguments=@('-version')},
        @{Name='Java';Command='java';Arguments=@('-version')},
        @{Name='7-Zip';Command='7z';Arguments=@()},
        @{Name='Inkscape';Command='inkscape';Arguments=@('--version')},
        @{Name='VS Code';Command='code';Arguments=@('--version')}
    )
    foreach ($tool in $tools) { Invoke-VersionCommand -Name $tool.Name -Command $tool.Command -Arguments $tool.Arguments }
}

function Get-SecurityInventory {
    $antivirus = Get-SafeValue {
        @(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntiVirusProduct | ForEach-Object {
            [pscustomobject]@{ DisplayName=$_.displayName; ProductState=$_.productState; PathToSignedProductExe=$_.pathToSignedProductExe; PathToSignedReportingExe=$_.pathToSignedReportingExe }
        })
    } @()
    $firewall = Get-SafeValue {
        @(Get-NetFirewallProfile | ForEach-Object {
            [pscustomobject]@{ Name=$_.Name; Enabled=$_.Enabled; DefaultInboundAction=$_.DefaultInboundAction.ToString(); DefaultOutboundAction=$_.DefaultOutboundAction.ToString() }
        })
    } @()
    $bitlocker = Get-SafeValue {
        @(Get-BitLockerVolume | ForEach-Object {
            [pscustomobject]@{ MountPoint=$_.MountPoint; VolumeStatus=$_.VolumeStatus.ToString(); ProtectionStatus=$_.ProtectionStatus.ToString(); EncryptionPercentage=$_.EncryptionPercentage; EncryptionMethod=$_.EncryptionMethod.ToString() }
        })
    } @()
    [pscustomobject]@{ Antivirus=@($antivirus); FirewallProfiles=@($firewall); BitLocker=@($bitlocker) }
}

function Export-TableCsv($Data,[string]$Path) {
    @($Data) | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding utf8BOM
}

function Convert-ToHtmlTable($Data,[string]$Title,[string]$EmptyText='Keine Einträge.') {
    $items = @($Data)
    if ($items.Count -eq 0) { return "<section><h2>$Title</h2><p>$EmptyText</p></section>" }
    "<section><h2>$Title <span class='count'>($($items.Count))</span></h2>$($items | ConvertTo-Html -Fragment)</section>"
}

function New-HtmlReport($Inventory,[string]$Path) {
    $computer=$Inventory.Hardware.Computer; $os=$Inventory.Hardware.OperatingSystem
    $overview=@([pscustomobject]@{
        Computer=$computer.ComputerName; Hersteller=$computer.Manufacturer; Modell=$computer.Model; Windows=$os.Caption
        Version=$os.Version; Build=$os.BuildNumber; RAM_GB=$computer.TotalMemoryGB; Inventurzeit=$Inventory.Metadata.CreatedAt
        PowerShell=$Inventory.Metadata.PowerShellVersion; Administrator=$Inventory.Metadata.IsAdministrator
    })
    $sections=@(
        Convert-ToHtmlTable $overview 'Systemübersicht'
        Convert-ToHtmlTable $Inventory.InstalledPrograms 'Installierte Desktop-Programme'
        Convert-ToHtmlTable ($Inventory.PortablePrograms.Programs | Select-Object Name,ProductVersion,CompanyName,ExecutableCount,PrimaryExecutable,Folder) 'Portable Programme'
        Convert-ToHtmlTable $Inventory.AppxPackages 'Microsoft-Store-/AppX-Pakete'
        Convert-ToHtmlTable ($Inventory.Services | Select-Object Name,DisplayName,State,StartMode,Company,Executable) 'Dienste'
        Convert-ToHtmlTable ($Inventory.StartupItems | Select-Object Name,Scope,Type,Command,Source) 'Autostarts'
        Convert-ToHtmlTable ($Inventory.ScheduledTasks | Select-Object TaskName,TaskPath,State,Author,Triggers,Actions) 'Geplante Aufgaben'
        Convert-ToHtmlTable ($Inventory.DevelopmentTools | Select-Object Name,Found,Version,Path) 'Entwicklungswerkzeuge'
        Convert-ToHtmlTable $Inventory.Hardware.Processors 'Prozessoren'
        Convert-ToHtmlTable $Inventory.Hardware.MemoryModules 'Arbeitsspeicher'
        Convert-ToHtmlTable $Inventory.Hardware.Graphics 'Grafik'
        Convert-ToHtmlTable $Inventory.Hardware.PhysicalDisks 'Physische Laufwerke'
        Convert-ToHtmlTable $Inventory.Hardware.Volumes 'Volumes'
        Convert-ToHtmlTable $Inventory.Network.Adapters 'Netzwerkadapter'
        Convert-ToHtmlTable $Inventory.Security.Antivirus 'Antivirus'
        Convert-ToHtmlTable $Inventory.Security.FirewallProfiles 'Firewallprofile'
        Convert-ToHtmlTable $Inventory.Security.BitLocker 'BitLocker'
    ) -join "`n"

    $html=@"
<!DOCTYPE html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Windows-Inventar – $($computer.ComputerName)</title>
<style>
:root{color-scheme:light dark}body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:Canvas;color:CanvasText}
header{padding:1.6rem 2rem;border-bottom:1px solid color-mix(in srgb,CanvasText 20%,transparent);position:sticky;top:0;background:color-mix(in srgb,Canvas 94%,transparent);backdrop-filter:blur(8px);z-index:2}
main{padding:1rem 2rem 3rem}h1{margin:0 0 .3rem;font-size:1.8rem}h2{margin-top:2.2rem}.muted,.count{opacity:.65;font-weight:normal}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:.8rem;margin:1rem 0 2rem}.card{border:1px solid color-mix(in srgb,CanvasText 18%,transparent);border-radius:.7rem;padding:1rem}.card strong{display:block;font-size:1.7rem}.card span{opacity:.72}
section{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:.9rem}th,td{border:1px solid color-mix(in srgb,CanvasText 16%,transparent);padding:.45rem .55rem;text-align:left;vertical-align:top;overflow-wrap:anywhere}th{position:sticky;top:104px;background:Canvas}tr:nth-child(even){background:color-mix(in srgb,CanvasText 4%,transparent)}
</style></head><body><header><h1>Windows-Inventar: $($computer.ComputerName)</h1><div class="muted">Erstellt am $($Inventory.Metadata.CreatedAt)</div></header><main>
<div class="cards"><div class="card"><strong>$($Inventory.InstalledPrograms.Count)</strong><span>installierte Programme</span></div><div class="card"><strong>$($Inventory.PortablePrograms.Programs.Count)</strong><span>portable Programmordner</span></div><div class="card"><strong>$($Inventory.Services.Count)</strong><span>erfasste Dienste</span></div><div class="card"><strong>$($Inventory.StartupItems.Count)</strong><span>Autostarts</span></div><div class="card"><strong>$($Inventory.ScheduledTasks.Count)</strong><span>geplante Aufgaben</span></div></div>
$sections
</main></body></html>
"@
    Set-Content -LiteralPath $Path -Value $html -Encoding utf8
}

$timestamp=Get-Date -Format 'yyyy-MM-dd_HHmmss'
$outputDirectory=Join-Path $OutputRoot "$env:COMPUTERNAME`_$timestamp"
$csvDirectory=Join-Path $outputDirectory 'CSV'
New-Item -ItemType Directory -Path $csvDirectory -Force | Out-Null

$isAdministrator=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Step 'Installierte Programme werden erfasst'; $installedPrograms=@(Get-RegistryInstalledApps)
Write-Step 'AppX-/Store-Pakete werden erfasst'; $appxPackages=@(Get-AppxInventory)
Write-Step "Portable Programme unter '$PortableRoot' werden erfasst"; $portablePrograms=Get-PortableInventory $PortableRoot
Write-Step 'Dienste werden erfasst'; $services=@(Get-ServiceInventory -IncludeMicrosoft:$IncludeMicrosoftServices)
Write-Step 'Autostarts werden erfasst'; $startupItems=@(Get-StartupInventory)
Write-Step 'Geplante Aufgaben werden erfasst'; $scheduledTasks=@(Get-ScheduledTaskInventory -IncludeMicrosoft:$IncludeMicrosoftTasks)
Write-Step 'Hardware wird erfasst'; $hardware=Get-HardwareInventory
Write-Step 'Netzwerk wird erfasst'; $network=Get-NetworkInventory
Write-Step 'Entwicklungswerkzeuge werden geprüft'; $developmentTools=@(Get-DevelopmentToolsInventory)
Write-Step 'Sicherheitsinformationen werden erfasst'; $security=Get-SecurityInventory

$inventory=[pscustomobject]@{
    Metadata=[pscustomobject]@{
        SchemaVersion='1.0'; CreatedAt=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'); ComputerName=$env:COMPUTERNAME
        UserName=[Environment]::UserName; IsAdministrator=$isAdministrator; PowerShellVersion=$PSVersionTable.PSVersion.ToString()
        PortableRoot=$PortableRoot; IncludeMicrosoftTasks=[bool]$IncludeMicrosoftTasks; IncludeMicrosoftServices=[bool]$IncludeMicrosoftServices
    }
    InstalledPrograms=$installedPrograms; AppxPackages=$appxPackages; PortablePrograms=$portablePrograms
    Services=$services; StartupItems=$startupItems; ScheduledTasks=$scheduledTasks; Hardware=$hardware
    Network=$network; DevelopmentTools=$developmentTools; Security=$security
}

$jsonPath=Join-Path $outputDirectory 'Inventory.json'
$inventory | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $jsonPath -Encoding utf8

Export-TableCsv $installedPrograms (Join-Path $csvDirectory 'InstalledPrograms.csv')
Export-TableCsv $appxPackages (Join-Path $csvDirectory 'AppxPackages.csv')
Export-TableCsv $portablePrograms.Programs (Join-Path $csvDirectory 'PortablePrograms.csv')
Export-TableCsv $services (Join-Path $csvDirectory 'Services.csv')
Export-TableCsv $startupItems (Join-Path $csvDirectory 'StartupItems.csv')
Export-TableCsv $scheduledTasks (Join-Path $csvDirectory 'ScheduledTasks.csv')
Export-TableCsv $developmentTools (Join-Path $csvDirectory 'DevelopmentTools.csv')
Export-TableCsv $hardware.Processors (Join-Path $csvDirectory 'Processors.csv')
Export-TableCsv $hardware.MemoryModules (Join-Path $csvDirectory 'MemoryModules.csv')
Export-TableCsv $hardware.Graphics (Join-Path $csvDirectory 'Graphics.csv')
Export-TableCsv $hardware.PhysicalDisks (Join-Path $csvDirectory 'PhysicalDisks.csv')
Export-TableCsv $hardware.Volumes (Join-Path $csvDirectory 'Volumes.csv')
Export-TableCsv $network.Adapters (Join-Path $csvDirectory 'NetworkAdapters.csv')

$htmlPath=Join-Path $outputDirectory 'Inventory.html'
New-HtmlReport $inventory $htmlPath

$summary=@"
Windows-Inventar
================
Computer:                $env:COMPUTERNAME
Erstellt:                 $($inventory.Metadata.CreatedAt)
PowerShell:               $($inventory.Metadata.PowerShellVersion)
Als Administrator:        $isAdministrator
Installierte Programme:   $($installedPrograms.Count)
AppX-Pakete:              $($appxPackages.Count)
Portable Programme:       $($portablePrograms.Programs.Count)
Erfasste Dienste:         $($services.Count)
Autostarts:               $($startupItems.Count)
Geplante Aufgaben:        $($scheduledTasks.Count)
Portable-Ordner:          $PortableRoot
Portable-Ordner existiert: $($portablePrograms.RootExists)
HTML-Bericht:             $htmlPath
JSON:                     $jsonPath
"@
Set-Content -LiteralPath (Join-Path $outputDirectory 'Summary.txt') -Value $summary -Encoding utf8
Write-Host "`n$summary"
Write-Host 'Inventur abgeschlossen.' -ForegroundColor Green
if($OpenReport){Start-Process $htmlPath}
