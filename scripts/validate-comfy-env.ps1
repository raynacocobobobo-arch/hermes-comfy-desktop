[CmdletBinding()]
param(
    [string]$ComfyRoot,
    [ValidateSet('single','triple')][string]$Mode = 'single',
    [string]$NodeListPath,
    [string]$ModelConfigPath,
    [string]$WorkflowRoot
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptRoot
. (Join-Path $ScriptRoot 'collect-system-info.ps1')

function Resolve-HermesModelDirectory {
    param(
        [Parameter(Mandatory)][string]$ComfyRoot,
        [Parameter(Mandatory)][string]$ExpectedFolder
    )
    if ([System.IO.Path]::IsPathRooted($ExpectedFolder)) {
        return [System.IO.Path]::GetFullPath($ExpectedFolder)
    }
    $normalized = $ExpectedFolder -replace '/', [System.IO.Path]::DirectorySeparatorChar
    return [System.IO.Path]::GetFullPath((Join-Path $ComfyRoot $normalized))
}

function Invoke-HermesComfyValidation {
    [CmdletBinding()]
    param(
        [string]$ComfyRoot,
        [ValidateSet('single','triple')][string]$Mode = 'single',
        [string]$NodeListPath,
        [string]$ModelConfigPath,
        [string]$WorkflowRoot
    )

    if (-not $NodeListPath) { $NodeListPath = Join-Path $RepoRoot 'config/node-list.json' }
    if (-not $ModelConfigPath) { $ModelConfigPath = Join-Path $RepoRoot 'config/model-recommendations.yaml' }
    if (-not $WorkflowRoot) { $WorkflowRoot = Join-Path $RepoRoot 'workflows' }

    $lines = New-Object System.Collections.Generic.List[string]
    $failures = 0

    function Add-Result([string]$Level, [string]$Message) {
        $lines.Add("$Level $Message")
        if ($Level -eq 'FAIL') { $script:__hermesValidationFailure = $true }
    }

    $script:__hermesValidationFailure = $false

    $info = Get-HermesComfySystemInfo -ComfyRoot $ComfyRoot
    if (-not $info.resolved_comfy_root) {
        Add-Result 'FAIL' "Comfy root unresolved or ambiguous. Candidates: $(@($info.comfy_candidates) -join ', ')"
        return [pscustomobject]@{ ok = $false; lines = @($lines); info = $info }
    }

    $resolvedRoot = $info.resolved_comfy_root
    Add-Result 'PASS' "Comfy root: $resolvedRoot"

    if (Test-Path $info.custom_nodes_path -PathType Container) {
        Add-Result 'PASS' "custom_nodes: $($info.custom_nodes_path)"
    } else {
        Add-Result 'FAIL' "custom_nodes missing: $($info.custom_nodes_path)"
    }

    if (Test-Path $info.models_path -PathType Container) {
        Add-Result 'PASS' "models: $($info.models_path)"
    } else {
        Add-Result 'FAIL' "models missing: $($info.models_path)"
    }

    if (-not (Test-Path $NodeListPath -PathType Leaf)) {
        Add-Result 'FAIL' "node config missing: $NodeListPath"
    } else {
        try {
            $nodeConfig = Get-Content $NodeListPath -Raw | ConvertFrom-Json
            foreach ($node in @($nodeConfig.nodes)) {
                $isRequired = @($node.required_for) -contains $Mode
                if ($isRequired) {
                    if ([string]::IsNullOrWhiteSpace([string]$node.resolved_repository) -or [string]::IsNullOrWhiteSpace([string]$node.folder_name)) {
                        Add-Result 'FAIL' "required node '$($node.id)' is unresolved"
                        continue
                    }
                    $nodeDir = Join-Path $info.custom_nodes_path $node.folder_name
                    if (Test-Path $nodeDir -PathType Container) {
                        Add-Result 'PASS' "required node '$($node.id)' directory present: $nodeDir"
                    } else {
                        Add-Result 'FAIL' "required node '$($node.id)' directory missing: $nodeDir"
                    }
                } else {
                    if ([string]::IsNullOrWhiteSpace([string]$node.folder_name)) {
                        Add-Result 'WARN' "optional node '$($node.id)' is unresolved"
                    } else {
                        $nodeDir = Join-Path $info.custom_nodes_path $node.folder_name
                        if (Test-Path $nodeDir -PathType Container) {
                            Add-Result 'PASS' "optional node '$($node.id)' directory present"
                        } else {
                            Add-Result 'WARN' "optional node '$($node.id)' directory missing: $nodeDir"
                        }
                    }
                }
            }
        } catch {
            Add-Result 'FAIL' "node config invalid: $($_.Exception.Message)"
        }
    }

    if (-not (Test-Path $ModelConfigPath -PathType Leaf)) {
        Add-Result 'FAIL' "model config missing: $ModelConfigPath"
    } else {
        try {
            $modelConfig = Get-Content $ModelConfigPath -Raw | ConvertFrom-Json
            foreach ($model in @($modelConfig.models)) {
                if (-not $model.required) { continue }
                if ([string]::IsNullOrWhiteSpace([string]$model.expected_folder) -or [string]::IsNullOrWhiteSpace([string]$model.resolved_filename)) {
                    Add-Result 'FAIL' "required model '$($model.id)' is unresolved"
                    continue
                }
                $dir = Resolve-HermesModelDirectory -ComfyRoot $resolvedRoot -ExpectedFolder $model.expected_folder
                $file = Join-Path $dir $model.resolved_filename
                if (Test-Path $file -PathType Leaf) {
                    Add-Result 'PASS' "required model '$($model.id)' present"
                } else {
                    Add-Result 'FAIL' "required model '$($model.id)' missing: $file"
                }
            }
        } catch {
            Add-Result 'FAIL' "model config invalid: $($_.Exception.Message)"
        }
    }

    if (Test-Path $WorkflowRoot -PathType Container) {
        $workflowFiles = @(Get-ChildItem $WorkflowRoot -Filter '*.json' -File -ErrorAction SilentlyContinue)
        if ($workflowFiles.Count -eq 0) {
            Add-Result 'WARN' 'no workflow JSON files present yet'
        }
        foreach ($workflow in $workflowFiles) {
            try {
                $raw = Get-Content $workflow.FullName -Raw
                $null = $raw | ConvertFrom-Json
                if ($raw -match '__UNRESOLVED_NODE_CLASS__') {
                    Add-Result 'FAIL' "workflow contains unresolved node marker: $($workflow.Name)"
                } else {
                    Add-Result 'PASS' "workflow parses: $($workflow.Name)"
                }
            } catch {
                Add-Result 'FAIL' "workflow invalid '$($workflow.Name)': $($_.Exception.Message)"
            }
        }
    } else {
        Add-Result 'WARN' "workflow directory missing: $WorkflowRoot"
    }

    try {
        $driveName = ([System.IO.Path]::GetPathRoot($resolvedRoot)).TrimEnd('\').TrimEnd(':')
        $drive = Get-PSDrive -Name $driveName -ErrorAction Stop
        $freeGb = [math]::Round($drive.Free / 1GB, 1)
        Add-Result 'PASS' "disk free: ${freeGb} GB"
    } catch {
        Add-Result 'WARN' "disk free diagnostic unavailable: $($_.Exception.Message)"
    }

    $ok = -not $script:__hermesValidationFailure
    Remove-Variable __hermesValidationFailure -Scope Script -ErrorAction SilentlyContinue
    return [pscustomobject]@{ ok = $ok; lines = @($lines); info = $info }
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = Invoke-HermesComfyValidation -ComfyRoot $ComfyRoot -Mode $Mode -NodeListPath $NodeListPath -ModelConfigPath $ModelConfigPath -WorkflowRoot $WorkflowRoot
    foreach ($line in $result.lines) { Write-Host $line }
    if ($result.ok) { exit 0 } else { exit 1 }
}
