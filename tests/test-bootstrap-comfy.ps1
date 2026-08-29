$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$bootstrap = Join-Path $RepoRoot 'scripts/bootstrap-comfy.ps1'
$git = Get-Command git -ErrorAction Stop

function New-FakeComfyRoot {
    $root = Join-Path $env:TEMP ('hermes-bootstrap-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path (Join-Path $root 'custom_nodes') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'models') -Force | Out-Null
    return $root
}

function Write-NodeConfig {
    param([string]$Path, [object[]]$Nodes)
    @{ schema_version=1; nodes=$Nodes } | ConvertTo-Json -Depth 6 | Set-Content $Path -Encoding utf8
}

function Assert-GitOrigin {
    param([string]$Target, [string]$Expected)
    $actual = (& $git.Source -C $Target remote get-url origin 2>&1 | Select-Object -First 1)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) { throw "test fixture could not read git origin at ${Target}: $actual" }
    if ([string]$actual -ne $Expected) { throw "test fixture git origin mismatch. Expected='$Expected' Actual='$actual'" }
}

# Missing git fails before any clone.
$root = New-FakeComfyRoot
try {
    $cfg = Join-Path $root 'nodes.json'
    Write-NodeConfig $cfg @(@{ id='identity'; required_for=@('single'); resolved_repository='https://example.invalid/identity.git'; folder_name='IdentityNode' })
    $out = & pwsh -NoProfile -File $bootstrap -ComfyRoot $root -NodeListPath $cfg -GitExecutable '__missing_hermes_git__' 2>&1
    if ($LASTEXITCODE -eq 0) { throw 'missing git should fail' }
} finally { Remove-Item $root -Recurse -Force }

# Unresolved required package fails.
$root = New-FakeComfyRoot
try {
    $cfg = Join-Path $root 'nodes.json'
    Write-NodeConfig $cfg @(@{ id='identity'; required_for=@('single'); resolved_repository=$null; folder_name=$null })
    $out = & pwsh -NoProfile -File $bootstrap -ComfyRoot $root -NodeListPath $cfg 2>&1
    if ($LASTEXITCODE -eq 0) { throw 'unresolved required node should fail bootstrap' }
} finally { Remove-Item $root -Recurse -Force }

# Existing non-git target fails.
$root = New-FakeComfyRoot
try {
    $cfg = Join-Path $root 'nodes.json'
    Write-NodeConfig $cfg @(@{ id='identity'; required_for=@('single'); resolved_repository='https://example.invalid/identity.git'; folder_name='IdentityNode' })
    New-Item -ItemType Directory -Path (Join-Path $root 'custom_nodes/IdentityNode') -Force | Out-Null
    $out = & pwsh -NoProfile -File $bootstrap -ComfyRoot $root -NodeListPath $cfg 2>&1
    if ($LASTEXITCODE -eq 0) { throw 'existing non-git node folder should fail' }
} finally { Remove-Item $root -Recurse -Force }

# Mismatched git origin fails.
$root = New-FakeComfyRoot
try {
    $cfg = Join-Path $root 'nodes.json'
    Write-NodeConfig $cfg @(@{ id='identity'; required_for=@('single'); resolved_repository='https://example.invalid/expected.git'; folder_name='IdentityNode' })
    $target = Join-Path $root 'custom_nodes/IdentityNode'
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    & $git.Source -C $target init | Out-Null
    & $git.Source -C $target remote add origin 'https://example.invalid/other.git'
    Assert-GitOrigin -Target $target -Expected 'https://example.invalid/other.git'
    $out = & pwsh -NoProfile -File $bootstrap -ComfyRoot $root -NodeListPath $cfg 2>&1
    if ($LASTEXITCODE -eq 0) { throw 'mismatched git origin should fail' }
} finally { Remove-Item $root -Recurse -Force }

# Matching existing repository is skipped, not reset.
$root = New-FakeComfyRoot
try {
    $cfg = Join-Path $root 'nodes.json'
    $remote = 'https://example.invalid/identity.git'
    Write-NodeConfig $cfg @(@{ id='identity'; required_for=@('single'); resolved_repository=$remote; folder_name='IdentityNode' })
    $target = Join-Path $root 'custom_nodes/IdentityNode'
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    & $git.Source -C $target init | Out-Null
    & $git.Source -C $target remote add origin $remote
    Assert-GitOrigin -Target $target -Expected $remote
    Set-Content (Join-Path $target 'keep-me.txt') 'preserve' -Encoding utf8
    $out = & pwsh -NoProfile -File $bootstrap -ComfyRoot $root -NodeListPath $cfg 2>&1
    if ($LASTEXITCODE -ne 0) { throw "matching existing repo should pass: $($out -join ' | ')" }
    if (($out -join "`n") -notmatch 'SKIP matching node') { throw 'matching repo should report SKIP' }
    if (-not (Test-Path (Join-Path $target 'keep-me.txt'))) { throw 'bootstrap altered matching repository contents' }
} finally { Remove-Item $root -Recurse -Force }

Write-Host 'PASS bootstrap tests'
