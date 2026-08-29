$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

$rolePath = Join-Path $RepoRoot 'config/asset-role-map.yaml'
$nodePath = Join-Path $RepoRoot 'config/node-list.json'
$modelPath = Join-Path $RepoRoot 'config/model-recommendations.yaml'

foreach ($path in @($rolePath, $nodePath, $modelPath)) {
    if (-not (Test-Path $path)) { throw "Missing config: $path" }
}

$roles = Get-Content $rolePath -Raw | ConvertFrom-Json
$nodes = Get-Content $nodePath -Raw | ConvertFrom-Json
$models = Get-Content $modelPath -Raw | ConvertFrom-Json

$expectedSlots = @('face','body','wardrobe','pose','scene')
foreach ($slot in $expectedSlots) {
    if (-not $roles.slots.PSObject.Properties.Name.Contains($slot)) {
        throw "Missing role slot: $slot"
    }
}

if ($roles.schema_version -ne 1) { throw 'asset-role-map schema_version must be 1' }
if ($nodes.schema_version -ne 1) { throw 'node-list schema_version must be 1' }
if ($models.schema_version -ne 1) { throw 'model-recommendations schema_version must be 1' }

if ($roles.slots.face.hermes_role -ne 'IDENTITY ONLY') { throw 'face role mismatch' }
if ($roles.slots.body.hermes_role -ne 'BODY ONLY') { throw 'body role mismatch' }
if ($roles.slots.wardrobe.hermes_role -ne 'WARDROBE ONLY') { throw 'wardrobe role mismatch' }
if ($roles.slots.pose.hermes_role -ne 'POSE ONLY') { throw 'pose role mismatch' }
if ($roles.slots.scene.hermes_role -ne 'SCENE ONLY') { throw 'scene role mismatch' }

if (-not $roles.slots.face.may_define_identity) { throw 'face must be allowed to define identity' }
foreach ($slot in @('body','wardrobe','pose','scene')) {
    if ($roles.slots.$slot.may_define_identity) { throw "$slot must not define identity" }
}

if (-not $nodes.nodes -or $nodes.nodes.Count -lt 3) { throw 'node-list.json has insufficient nodes' }
if (-not $models.models -or $models.models.Count -lt 5) { throw 'model-recommendations.yaml has insufficient models' }

$requiredModelIds = @('sdxl_checkpoint','identity_model','clip_vision_adapter','pose_controlnet_sdxl','pose_preprocessor')
foreach ($id in $requiredModelIds) {
    if (-not ($models.models.id -contains $id)) { throw "Missing model metadata: $id" }
}

Write-Host 'PASS config validation'
