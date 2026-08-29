[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][string]$ComfyRoot,
    [ValidateSet('single','triple')][string]$Mode = 'single',
    [string]$NodeListPath,
    [string]$GitExecutable = 'git'
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptRoot
. (Join-Path $ScriptRoot 'collect-system-info.ps1')

function Normalize-HermesGitRemote {
    param([Parameter(Mandatory)][string]$Remote)
    $value = $Remote.Trim().TrimEnd('/')
    if ($value.EndsWith('.git', [System.StringComparison]::OrdinalIgnoreCase)) {
        $value = $value.Substring(0, $value.Length - 4)
    }
    return $value.ToLowerInvariant()
}

function Invoke-HermesComfyBootstrap {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$ComfyRoot,
        [ValidateSet('single','triple')][string]$Mode = 'single',
        [string]$NodeListPath,
        [string]$GitExecutable = 'git'
    )

    if (-not $NodeListPath) { $NodeListPath = Join-Path $RepoRoot 'config/node-list.json' }
    if (-not (Test-Path $NodeListPath -PathType Leaf)) { throw "Node config missing: $NodeListPath" }

    $git = Get-Command $GitExecutable -ErrorAction SilentlyContinue
    if (-not $git) { throw "Git executable not available: $GitExecutable" }

    $info = Get-HermesComfySystemInfo -ComfyRoot $ComfyRoot
    if (-not $info.resolved_comfy_root) {
        throw "Comfy root unresolved or ambiguous. Candidates: $(@($info.comfy_candidates) -join ', ')"
    }
    if (-not (Test-Path $info.custom_nodes_path -PathType Container)) {
        throw "custom_nodes directory missing: $($info.custom_nodes_path)"
    }

    $config = Get-Content $NodeListPath -Raw | ConvertFrom-Json
    $requiredNodes = @($config.nodes | Where-Object { @($_.required_for) -contains $Mode })
    if ($requiredNodes.Count -eq 0) { throw "No required nodes declared for mode: $Mode" }

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($node in $requiredNodes) {
        if ([string]::IsNullOrWhiteSpace([string]$node.resolved_repository)) {
            throw "Required node '$($node.id)' has unresolved_repository=null. Verify compatibility before bootstrap."
        }
        if ([string]::IsNullOrWhiteSpace([string]$node.folder_name)) {
            throw "Required node '$($node.id)' has folder_name=null. Verify compatibility before bootstrap."
        }

        $remote = [string]$node.resolved_repository
        $target = Join-Path $info.custom_nodes_path ([string]$node.folder_name)

        if (Test-Path $target) {
            if (-not (Test-Path (Join-Path $target '.git') -PathType Container)) {
                throw "Existing target is not a git repository: $target"
            }

            $originOutput = @(& $git.Source -C $target remote get-url origin 2>$null)
            $originExitCode = $LASTEXITCODE
            $origin = [string]($originOutput | Select-Object -First 1)
            if ($originExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($origin)) {
                throw "Could not read git origin for existing node: $target (exit=$originExitCode origin='$origin')"
            }
            if ((Normalize-HermesGitRemote -Remote $origin) -ne (Normalize-HermesGitRemote -Remote $remote)) {
                throw "Existing node origin mismatch for '$($node.id)'. Existing='$origin' Expected='$remote'"
            }
            Write-Host "SKIP matching node '$($node.id)': $target"
            $results.Add([pscustomobject]@{ id=$node.id; action='skip'; path=$target })
            continue
        }

        if ($PSCmdlet.ShouldProcess($target, "git clone $remote")) {
            & $git.Source clone --depth 1 $remote $target
            if ($LASTEXITCODE -ne 0) { throw "git clone failed for '$($node.id)' from $remote" }
            Write-Host "INSTALLED node '$($node.id)': $target"
            $results.Add([pscustomobject]@{ id=$node.id; action='installed'; path=$target })
        } else {
            Write-Host "WHATIF node '$($node.id)': $target"
            $results.Add([pscustomobject]@{ id=$node.id; action='whatif'; path=$target })
        }
    }

    Write-Host 'NOTE model weights are never downloaded by bootstrap-comfy.ps1'
    return @($results)
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-HermesComfyBootstrap -ComfyRoot $ComfyRoot -Mode $Mode -NodeListPath $NodeListPath -GitExecutable $GitExecutable -WhatIf:$WhatIfPreference | Out-Null
}
