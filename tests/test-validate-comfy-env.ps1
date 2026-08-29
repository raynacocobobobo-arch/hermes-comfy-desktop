$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $RepoRoot 'scripts/validate-comfy-env.ps1'

function New-FakeComfyRoot {
    $root = Join-Path $env:TEMP ('hermes-comfy-validate-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path (Join-Path $root 'custom_nodes') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'models') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'workflows') -Force | Out-Null
    return $root
}

$root1 = New-FakeComfyRoot
try {
    $nodeConfig1 = Join-Path $root1 'nodes.json'
    $modelConfig1 = Join-Path $root1 'models.json'
    @{
        schema_version = 1
        nodes = @(
            @{ id='identity'; required_for=@('single'); resolved_repository=$null; folder_name=$null }
        )
    } | ConvertTo-Json -Depth 5 | Set-Content $nodeConfig1 -Encoding utf8
    @{ schema_version=1; models=@() } | ConvertTo-Json -Depth 5 | Set-Content $modelConfig1 -Encoding utf8

    $output = & pwsh -NoProfile -File $validator -ComfyRoot $root1 -NodeListPath $nodeConfig1 -ModelConfigPath $modelConfig1 -WorkflowRoot (Join-Path $root1 'workflows') 2>&1
    if ($LASTEXITCODE -eq 0) { throw 'unresolved required node should fail validation' }
    if (($output -join "`n") -notmatch "FAIL required node 'identity' is unresolved") { throw 'missing unresolved-node FAIL output' }
} finally {
    Remove-Item $root1 -Recurse -Force
}

$root2 = New-FakeComfyRoot
try {
    foreach ($folder in @('IdentityNode','ReferenceNode','PoseNode')) {
        New-Item -ItemType Directory -Path (Join-Path (Join-Path $root2 'custom_nodes') $folder) -Force | Out-Null
    }

    $modelSpecs = @(
        @{ id='sdxl_checkpoint'; folder='models/checkpoints'; file='base.safetensors' },
        @{ id='identity_model'; folder='models/identity-test'; file='identity.bin.test' },
        @{ id='clip_vision_adapter'; folder='models/clip_vision'; file='adapter.bin.test' },
        @{ id='pose_controlnet_sdxl'; folder='models/controlnet'; file='pose.bin.test' },
        @{ id='pose_preprocessor'; folder='models/pose-preprocessor'; file='pose-pre.bin.test' }
    )
    foreach ($spec in $modelSpecs) {
        $dir = Join-Path $root2 ($spec.folder -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -Path (Join-Path $dir $spec.file) -Value 'test' -Encoding utf8
    }

    $nodeConfig2 = Join-Path $root2 'nodes.json'
    $modelConfig2 = Join-Path $root2 'models.json'
    @{
        schema_version = 1
        nodes = @(
            @{ id='identity'; required_for=@('single'); resolved_repository='https://example.invalid/identity.git'; folder_name='IdentityNode' },
            @{ id='reference_adapter'; required_for=@('single'); resolved_repository='https://example.invalid/reference.git'; folder_name='ReferenceNode' },
            @{ id='pose_preprocessor'; required_for=@('single'); resolved_repository='https://example.invalid/pose.git'; folder_name='PoseNode' },
            @{ id='face_detail'; required_for=@(); resolved_repository=$null; folder_name=$null }
        )
    } | ConvertTo-Json -Depth 6 | Set-Content $nodeConfig2 -Encoding utf8

    @{
        schema_version = 1
        models = @($modelSpecs | ForEach-Object {
            @{ id=$_.id; required=$true; expected_folder=$_.folder; resolved_filename=$_.file }
        })
    } | ConvertTo-Json -Depth 6 | Set-Content $modelConfig2 -Encoding utf8

    '{"meta":"valid workflow"}' | Set-Content (Join-Path $root2 'workflows/test.json') -Encoding utf8

    $output2 = & pwsh -NoProfile -File $validator -ComfyRoot $root2 -NodeListPath $nodeConfig2 -ModelConfigPath $modelConfig2 -WorkflowRoot (Join-Path $root2 'workflows') 2>&1
    if ($LASTEXITCODE -ne 0) { throw "resolved required environment should pass: $($output2 -join ' | ')" }
    if (($output2 -join "`n") -notmatch "WARN optional node 'face_detail' is unresolved") { throw 'optional unresolved node should warn' }
} finally {
    Remove-Item $root2 -Recurse -Force
}

Write-Host 'PASS environment-validator tests'
