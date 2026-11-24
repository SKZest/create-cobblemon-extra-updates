param(
    [string]$Root = $PSScriptRoot,
    [switch]$PruebaLocal
)

$ErrorActionPreference = 'Stop'

function Read-Json([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Save-Json([string]$Path, [object]$Value) {
    $temporary = "$Path.tmp"
    [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Fetch-File([string]$Url, [string]$Destination) {
    $uri = [Uri]::new($Url)
    if ($uri.Scheme -eq 'file' -and $PruebaLocal) {
        Copy-Item -LiteralPath $uri.LocalPath -Destination $Destination -Force
    } elseif ($uri.Scheme -eq 'https') {
        if ($uri.Host -notin @('github.com', 'api.github.com')) {
            throw "Servidor de descarga no permitido: $($uri.Host)"
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -TimeoutSec 60
    } else {
        throw "Direccion de descarga no permitida: $Url"
    }
}

function Resolve-ManagedFile([string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or $Relative.Contains('\') -or $Relative.Contains(':')) {
        throw "Ruta invalida en el parche: $Relative"
    }
    $parts = $Relative.Split('/')
    if ($parts.Count -lt 3 -or $parts[0] -cne '.minecraft') {
        throw "Ruta fuera del modpack: $Relative"
    }
    foreach ($part in $parts) {
        if ($part -in @('', '.', '..')) { throw "Ruta invalida en el parche: $Relative" }
    }
    $allowed = @(
        '.minecraft/mods/',
        '.minecraft/config/',
        '.minecraft/defaultconfigs/',
        '.minecraft/global_packs/',
        '.minecraft/resourcepacks/',
        '.minecraft/datapacks/',
        '.minecraft/fancymenu_data/'
    )
    if (-not @($allowed | Where-Object { $Relative.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count) {
        throw "Archivo personal o del juego no actualizable: $Relative"
    }
    $full = [IO.Path]::GetFullPath((Join-Path $Root ($Relative -replace '/', '\')))
    $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Ruta fuera del modpack: $Relative"
    }
    return $full
}

$Root = [IO.Path]::GetFullPath($Root)
$configPath = Join-Path $Root 'actualizaciones.config.json'
$statePath = Join-Path $Root 'actualizaciones.estado.json'
$updates = Join-Path $Root 'actualizaciones'

try {
    $config = Read-Json $configPath
    $state = Read-Json $statePath
    $current = [int]$state.version
    if (-not $config.manifestUrl) { throw 'Falta la direccion de las actualizaciones.' }
    New-Item -ItemType Directory -Force -Path $updates | Out-Null

    $manifestFile = Join-Path $updates 'manifest-descargado.json'
    try {
        Fetch-File $config.manifestUrl $manifestFile
    } catch {
        Write-Host "No pude comprobar actualizaciones: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host 'Se iniciara la version instalada.'
        exit 0
    }
    $manifest = Read-Json $manifestFile
    if ([int]$manifest.schema -ne 1) { throw 'Formato de actualizaciones desconocido.' }
    $latest = [int]$manifest.latest
    if ($latest -lt $current) { throw 'La version publicada es anterior a la instalada.' }
    if ($latest -eq $current) {
        Write-Host "Modpack actualizado (version $current)."
        exit 0
    }

    Add-Type -AssemblyName System.IO.Compression
    while ($current -lt $latest) {
        $patch = @($manifest.patches | Where-Object { [int]$_.from -eq $current }) | Select-Object -First 1
        if (-not $patch) { throw "Falta el parche que comienza en la version $current." }
        $next = [int]$patch.to
        if ($next -le $current -or $next -gt $latest) { throw 'Secuencia de parches invalida.' }
        if ([string]$patch.sha256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'Falta la suma de verificacion del parche.' }

        $download = Join-Path $updates ("parche-$current-a-$next.zip")
        Write-Host "Descargando actualizacion $current -> $next..."
        Fetch-File $patch.url $download
        $actualHash = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash
        if ($actualHash -ine [string]$patch.sha256) { throw 'La descarga no coincide con la suma de verificacion publicada.' }

        $archive = [IO.Compression.ZipFile]::OpenRead($download)
        try {
            $description = $archive.GetEntry('patch.json')
            if (-not $description) { throw 'El parche no tiene patch.json.' }
            $reader = [IO.StreamReader]::new($description.Open())
            try { $patchInfo = $reader.ReadToEnd() | ConvertFrom-Json }
            finally { $reader.Dispose() }
            if ([int]$patchInfo.schema -ne 1 -or [int]$patchInfo.from -ne $current -or [int]$patchInfo.to -ne $next) {
                throw 'La version interna del parche no coincide.'
            }

            $files = @()
            $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($entry in $archive.Entries) {
                if ($entry.FullName -eq 'patch.json' -or $entry.FullName.EndsWith('/')) { continue }
                if (-not $entry.FullName.StartsWith('files/', [StringComparison]::Ordinal)) {
                    throw "Entrada inesperada en el parche: $($entry.FullName)"
                }
                $relative = $entry.FullName.Substring(6)
                $target = Resolve-ManagedFile $relative
                if (-not $seen.Add($relative)) { throw "Archivo duplicado: $relative" }
                $files += [pscustomobject]@{ Relative = $relative; Target = $target; Entry = $entry }
            }
            $deletes = @()
            foreach ($relative in @($patchInfo.delete)) {
                $target = Resolve-ManagedFile ([string]$relative)
                if (-not $seen.Add([string]$relative)) { throw "Ruta repetida: $relative" }
                $deletes += [pscustomobject]@{ Relative = [string]$relative; Target = $target }
            }
            if ($files.Count -eq 0 -and $deletes.Count -eq 0) { throw 'El parche esta vacio.' }

            $backup = Join-Path $updates ("respaldo-$current-a-$next-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
            $staging = Join-Path $updates ("preparado-$current-a-$next")
            New-Item -ItemType Directory -Force -Path $backup, $staging | Out-Null
            $affected = @($files) + @($deletes)
            foreach ($item in $affected) {
                $item | Add-Member -NotePropertyName Existed -NotePropertyValue (Test-Path -LiteralPath $item.Target)
                if ($item.Existed) {
                    $backupPath = Join-Path $backup ($item.Relative -replace '/', '\')
                    New-Item -ItemType Directory -Force -Path (Split-Path $backupPath) | Out-Null
                    Copy-Item -LiteralPath $item.Target -Destination $backupPath -Force
                }
            }
            foreach ($item in $files) {
                $stagedPath = Join-Path $staging ($item.Relative -replace '/', '\')
                New-Item -ItemType Directory -Force -Path (Split-Path $stagedPath) | Out-Null
                $source = $item.Entry.Open()
                $destination = [IO.File]::Create($stagedPath)
                try { $source.CopyTo($destination) }
                finally { $destination.Dispose(); $source.Dispose() }
            }

            try {
                foreach ($item in $files) {
                    $stagedPath = Join-Path $staging ($item.Relative -replace '/', '\')
                    New-Item -ItemType Directory -Force -Path (Split-Path $item.Target) | Out-Null
                    Copy-Item -LiteralPath $stagedPath -Destination $item.Target -Force
                }
                foreach ($item in $deletes) {
                    if (Test-Path -LiteralPath $item.Target) { Remove-Item -LiteralPath $item.Target -Force }
                }
                $state.version = $next
                Save-Json $statePath $state
            } catch {
                foreach ($item in $affected) {
                    if ($item.Existed) {
                        $backupPath = Join-Path $backup ($item.Relative -replace '/', '\')
                        Copy-Item -LiteralPath $backupPath -Destination $item.Target -Force
                    } elseif (Test-Path -LiteralPath $item.Target) {
                        Remove-Item -LiteralPath $item.Target -Force
                    }
                }
                throw
            }

            $current = $next
            Write-Host "Actualizacion $current instalada. Respaldo: $backup" -ForegroundColor Green
        } finally {
            $archive.Dispose()
        }
    }
} catch {
    Write-Host "No se pudo actualizar: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

