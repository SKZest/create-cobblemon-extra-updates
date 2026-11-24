param(
    [Parameter(Mandatory=$true)][string]$PortableRoot,
    [Parameter(Mandatory=$true)][int]$From,
    [Parameter(Mandatory=$true)][int]$To,
    [Parameter(Mandatory=$true)][string[]]$Files,
    [string[]]$Delete = @(),
    [string]$PreviousManifest = (Join-Path $PSScriptRoot 'updates-inicial.json'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'salida'),
    [string]$ReleaseBase = 'https://github.com/SKZest/create-cobblemon-extra-updates/releases/download'
)

$ErrorActionPreference = 'Stop'
if ($To -ne ($From + 1)) { throw 'Las versiones deben ser consecutivas.' }
$PortableRoot = [IO.Path]::GetFullPath($PortableRoot)
$allowed = @(
    '.minecraft/mods/', '.minecraft/config/', '.minecraft/defaultconfigs/',
    '.minecraft/global_packs/', '.minecraft/resourcepacks/',
    '.minecraft/datapacks/', '.minecraft/fancymenu_data/'
)
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

function Validate-Relative([string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or $Relative.Contains('\') -or $Relative.Contains(':')) {
        throw "Ruta invalida: $Relative"
    }
    $parts = $Relative.Split('/')
    if ($parts.Count -lt 3 -or $parts[0] -cne '.minecraft') { throw "Ruta invalida: $Relative" }
    foreach ($part in $parts) { if ($part -in @('', '.', '..')) { throw "Ruta invalida: $Relative" } }
    if (-not @($allowed | Where-Object { $Relative.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count) {
        throw "Archivo personal fuera de los parches: $Relative"
    }
    if (-not $seen.Add($Relative)) { throw "Ruta repetida: $Relative" }
}

foreach ($relative in $Files) { Validate-Relative $relative }
foreach ($relative in $Delete) { Validate-Relative $relative }

$previous = Get-Content -LiteralPath $PreviousManifest -Raw -Encoding UTF8 | ConvertFrom-Json
if ([int]$previous.schema -ne 1 -or [int]$previous.latest -ne $From) {
    throw 'La version anterior del manifiesto no coincide con From.'
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$patchName = "patch-$From-$To.zip"
$patchPath = Join-Path $OutputDirectory $patchName
if (Test-Path -LiteralPath $patchPath) { throw "Ya existe $patchPath. Usa otra carpeta de salida." }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($patchPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    $description = [ordered]@{ schema = 1; from = $From; to = $To; delete = @($Delete) }
    $entry = $archive.CreateEntry('patch.json')
    $writer = [IO.StreamWriter]::new($entry.Open(), [Text.UTF8Encoding]::new($false))
    try { $writer.Write(($description | ConvertTo-Json -Depth 10)) }
    finally { $writer.Dispose() }
    foreach ($relative in $Files) {
        $source = Join-Path $PortableRoot ($relative -replace '/', '\')
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Falta el archivo: $source" }
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $source, "files/$relative", [IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $archive.Dispose()
}

$patchInfo = [ordered]@{
    from = $From
    to = $To
    url = "$($ReleaseBase.TrimEnd('/'))/v$To/$patchName"
    sha256 = (Get-FileHash -LiteralPath $patchPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
$manifest = [ordered]@{
    schema = 1
    latest = $To
    patches = @($previous.patches) + @($patchInfo)
}
$manifestPath = Join-Path $OutputDirectory 'updates.json'
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
Write-Host "Parche: $patchPath"
Write-Host "Manifiesto: $manifestPath"
Write-Host "Archivos: $($Files.Count); eliminaciones: $($Delete.Count)"

