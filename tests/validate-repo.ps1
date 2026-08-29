[CmdletBinding()]
param(
    [switch]$AllowIncompleteWorkflows,
    [switch]$AllowMissingTripleWorkflow
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot 'validate-config.ps1')
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'validate-config.ps1 failed' }

$coreRequired = @(
    'README.md',
    'config/asset-role-map.yaml',
    'config/node-list.json',
    'config/model-recommendations.yaml',
    'docs/setup-windows-rtx4060.md',
    'templates/shot-contract-template.md',
    'templates/generation-checklist.md',
    'scripts/collect-system-info.ps1',
    'scripts/validate-comfy-env.ps1',
    'tests/validate-config.ps1',
    'tests/validate-repo.ps1'
)
foreach ($relative in $coreRequired) {
    if (-not (Test-Path (Join-Path $RepoRoot $relative) -PathType Leaf)) { throw "Missing required repository file: $relative" }
}

if (-not $AllowIncompleteWorkflows) {
    $laterRequired = @(
        'docs/workflow-design.md',
        'docs/codex-local-runbook.md',
        'docs/troubleshooting.md',
        'scripts/bootstrap-comfy.ps1',
        'scripts/link-workflows.ps1',
        'workflows/hermes-dh-v1-single.json',
        'workflows/workflow-notes.md'
    )
    if (-not $AllowMissingTripleWorkflow) { $laterRequired += 'workflows/hermes-dh-v1-triple.json' }
    foreach ($relative in $laterRequired) {
        if (-not (Test-Path (Join-Path $RepoRoot $relative) -PathType Leaf)) { throw "Missing required repository file: $relative" }
    }
}

$workflowRoot = Join-Path $RepoRoot 'workflows'
if (Test-Path $workflowRoot -PathType Container) {
    foreach ($workflow in @(Get-ChildItem $workflowRoot -Filter '*.json' -File)) {
        $raw = Get-Content $workflow.FullName -Raw
        try { $null = $raw | ConvertFrom-Json } catch { throw "Invalid workflow JSON '$($workflow.Name)': $($_.Exception.Message)" }
        if (-not $AllowIncompleteWorkflows -and $raw -match '__UNRESOLVED_NODE_CLASS__') {
            throw "Unresolved node class marker in workflow: $($workflow.Name)"
        }
        if ($workflow.Name -eq 'hermes-dh-v1-triple.json' -and -not $AllowIncompleteWorkflows) {
            foreach ($shot in @('SHOT01','SHOT02','SHOT03')) {
                if ($raw -notmatch [regex]::Escape($shot)) { throw "Triple workflow missing shot identifier: $shot" }
            }
            if ($raw -match '"parallel_full_sampler_branches"\s*:\s*true') {
                throw 'Triple workflow may not enable parallel full sampler branches'
            }
        }
    }
}

$forbiddenExtensions = @('.safetensors','.ckpt','.pt','.pth','.bin')
$allFiles = @(Get-ChildItem $RepoRoot -Recurse -File -Force | Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]'
})

$forbidden = @($allFiles | Where-Object { $_.Extension.ToLowerInvariant() -in $forbiddenExtensions })
if ($forbidden.Count -gt 0) {
    throw "Forbidden model binary committed: $($forbidden.FullName -join ', ')"
}

$tooLarge = @($allFiles | Where-Object {
    $_.Length -gt 10MB -and $_.FullName -notmatch '[\\/]docs[\\/]'
})
if ($tooLarge.Count -gt 0) {
    throw "Unexpected file over 10 MB outside docs: $($tooLarge.FullName -join ', ')"
}

$imageExtensions = @('.png','.jpg','.jpeg','.webp','.bmp','.gif','.tiff')
$identityImages = @($allFiles | Where-Object {
    if ($_.Extension.ToLowerInvariant() -notin $imageExtensions) { return $false }
    $relative = $_.FullName.Substring($RepoRoot.Length).TrimStart('\','/')
    $segments = $relative -split '[\\/]'
    return @($segments | Where-Object { $_.ToLowerInvariant() -in @('identity','face','body') }).Count -gt 0
})
if ($identityImages.Count -gt 0) {
    throw "Identity/body image assets must not be committed: $($identityImages.FullName -join ', ')"
}

Write-Host 'PASS repository validation'
