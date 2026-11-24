param([Parameter(Mandatory=$true)][string]$GameDirectory)
$ErrorActionPreference = 'Stop'
$path = Join-Path $GameDirectory 'config\cobblemonintegrations-common.toml'
if (Test-Path -LiteralPath $path) {
    $text = [IO.File]::ReadAllText($path)
    $updated = $text.Replace('%trainer:hidden_when_wild\r\n', '')
    if ($updated -ne $text) {
        [IO.File]::WriteAllText($path, $updated, [Text.UTF8Encoding]::new($false))
    }
}

