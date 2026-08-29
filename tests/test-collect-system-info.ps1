$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $RepoRoot 'scripts/collect-system-info.ps1')

$temp = Join-Path $env:TEMP ('hermes-comfy-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $temp 'custom_nodes') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $temp 'models') -Force | Out-Null

try {
    $result = Get-HermesComfySystemInfo -ComfyRoot $temp
    $expected = [System.IO.Path]::GetFullPath($temp)
    if ($result.resolved_comfy_root -ne $expected) { throw 'explicit root not preserved' }
    if (-not $result.custom_nodes_path.EndsWith('custom_nodes')) { throw 'custom_nodes path missing' }
    if (-not $result.models_path.EndsWith('models')) { throw 'models path missing' }
    if ($result.comfy_candidates.Count -ne 1) { throw 'explicit root should resolve to exactly one candidate' }

    $outer = Join-Path $env:TEMP ('hermes-comfy-nested-' + [guid]::NewGuid())
    $nested = Join-Path $outer 'ComfyUI'
    New-Item -ItemType Directory -Path (Join-Path $nested 'custom_nodes') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $nested 'models') -Force | Out-Null
    try {
        $nestedResult = Get-HermesComfySystemInfo -ComfyRoot $outer
        if ($nestedResult.resolved_comfy_root -ne [System.IO.Path]::GetFullPath($nested)) { throw 'nested ComfyUI layout not resolved' }
    } finally {
        Remove-Item $outer -Recurse -Force
    }
} finally {
    Remove-Item $temp -Recurse -Force
}

Write-Host 'PASS system-info tests'
