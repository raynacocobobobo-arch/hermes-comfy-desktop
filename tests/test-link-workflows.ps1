$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$linker = Join-Path $RepoRoot 'scripts/link-workflows.ps1'

$fixture = Join-Path $env:TEMP ('hermes-link-' + [guid]::NewGuid())
$fakeRepo = Join-Path $fixture 'repo'
$comfy = Join-Path $fixture 'comfy'
$dest = Join-Path $fixture 'dest'
New-Item -ItemType Directory -Path (Join-Path $fakeRepo 'workflows') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $comfy 'custom_nodes') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $comfy 'models') -Force | Out-Null
New-Item -ItemType Directory -Path $dest -Force | Out-Null

try {
    $single = Join-Path $fakeRepo 'workflows/hermes-dh-v1-single.json'
    $triple = Join-Path $fakeRepo 'workflows/hermes-dh-v1-triple.json'
    '{"workflow":"single","value":1}' | Set-Content $single -Encoding utf8
    '{"workflow":"triple","shots":["SHOT01","SHOT02","SHOT03"]}' | Set-Content $triple -Encoding utf8

    # First copy succeeds.
    $out1 = & pwsh -NoProfile -File $linker -ComfyRoot $comfy -RepositoryRoot $fakeRepo -Destination $dest -Workflow single 2>&1
    if ($LASTEXITCODE -ne 0) { throw "first workflow copy failed: $($out1 -join ' | ')" }
    $installed = Join-Path $dest 'hermes-dh-v1-single.json'
    if (-not (Test-Path $installed)) { throw 'single workflow was not copied' }

    # Identical destination is skipped.
    $out2 = & pwsh -NoProfile -File $linker -ComfyRoot $comfy -RepositoryRoot $fakeRepo -Destination $dest -Workflow single 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'identical workflow should not fail' }
    if (($out2 -join "`n") -notmatch 'SKIP identical workflow') { throw 'identical workflow should report SKIP' }

    # Different destination stops by default.
    '{"workflow":"local-change"}' | Set-Content $installed -Encoding utf8
    $out3 = & pwsh -NoProfile -File $linker -ComfyRoot $comfy -RepositoryRoot $fakeRepo -Destination $dest -Workflow single 2>&1
    if ($LASTEXITCODE -eq 0) { throw 'different destination should fail with default Stop' }

    # Backup mode preserves local file then installs repository copy.
    $out4 = & pwsh -NoProfile -File $linker -ComfyRoot $comfy -RepositoryRoot $fakeRepo -Destination $dest -Workflow single -ConflictAction Backup 2>&1
    if ($LASTEXITCODE -ne 0) { throw "backup conflict handling failed: $($out4 -join ' | ')" }
    $backups = @(Get-ChildItem $dest -Filter 'hermes-dh-v1-single.backup-*.json' -File)
    if ($backups.Count -ne 1) { throw 'expected exactly one workflow backup' }
    if ((Get-Content $backups[0].FullName -Raw) -notmatch 'local-change') { throw 'backup did not preserve previous destination content' }
    if ((Get-FileHash $installed -Algorithm SHA256).Hash -ne (Get-FileHash $single -Algorithm SHA256).Hash) { throw 'repository source was not installed after backup' }

    # Triple is eligible and copies independently.
    $out5 = & pwsh -NoProfile -File $linker -ComfyRoot $comfy -RepositoryRoot $fakeRepo -Destination $dest -Workflow triple 2>&1
    if ($LASTEXITCODE -ne 0) { throw "triple workflow copy failed: $($out5 -join ' | ')" }
    if (-not (Test-Path (Join-Path $dest 'hermes-dh-v1-triple.json'))) { throw 'triple workflow missing after copy' }
} finally {
    Remove-Item $fixture -Recurse -Force
}

Write-Host 'PASS workflow-link tests'
