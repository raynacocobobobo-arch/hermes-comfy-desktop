[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][string]$ComfyRoot,
    [ValidateSet('single','triple','all')][string]$Workflow = 'single',
    [string]$Destination,
    [ValidateSet('Stop','Backup')][string]$ConflictAction = 'Stop',
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $ScriptRoot }

function Resolve-HermesWorkflowDestination {
    param(
        [Parameter(Mandatory)][string]$ComfyRoot,
        [string]$Destination
    )

    if ($Destination) {
        if (-not (Test-Path $Destination -PathType Container)) {
            throw "Explicit workflow destination does not exist: $Destination"
        }
        return [System.IO.Path]::GetFullPath($Destination)
    }

    $candidates = @(
        (Join-Path $ComfyRoot 'user\default\workflows'),
        (Join-Path $ComfyRoot 'workflows')
    ) | Where-Object { Test-Path $_ -PathType Container } | ForEach-Object { [System.IO.Path]::GetFullPath($_) } | Select-Object -Unique

    if (@($candidates).Count -eq 1) { return @($candidates)[0] }
    if (@($candidates).Count -eq 0) { throw 'No known workflow destination found. Supply -Destination explicitly.' }
    throw "Workflow destination is ambiguous. Supply -Destination explicitly. Candidates: $(@($candidates) -join ', ')"
}

function Get-HermesWorkflowSourceFiles {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [ValidateSet('single','triple','all')][string]$Workflow
    )

    $map = @{
        single = @('hermes-dh-v1-single.json')
        triple = @('hermes-dh-v1-triple.json')
        all = @('hermes-dh-v1-single.json','hermes-dh-v1-triple.json')
    }
    $workflowRoot = Join-Path $RepositoryRoot 'workflows'
    $files = @()
    foreach ($name in $map[$Workflow]) {
        $path = Join-Path $workflowRoot $name
        if (-not (Test-Path $path -PathType Leaf)) { throw "Workflow source missing: $path" }
        $files += Get-Item $path
    }
    return @($files)
}

function Install-HermesWorkflows {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$ComfyRoot,
        [ValidateSet('single','triple','all')][string]$Workflow = 'single',
        [string]$Destination,
        [ValidateSet('Stop','Backup')][string]$ConflictAction = 'Stop',
        [Parameter(Mandatory)][string]$RepositoryRoot
    )

    if (-not (Test-Path $ComfyRoot -PathType Container)) { throw "Comfy root does not exist: $ComfyRoot" }
    $destRoot = Resolve-HermesWorkflowDestination -ComfyRoot $ComfyRoot -Destination $Destination
    $sources = Get-HermesWorkflowSourceFiles -RepositoryRoot $RepositoryRoot -Workflow $Workflow

    foreach ($source in $sources) {
        $dest = Join-Path $destRoot $source.Name
        if (Test-Path $dest -PathType Leaf) {
            $sourceHash = (Get-FileHash $source.FullName -Algorithm SHA256).Hash
            $destHash = (Get-FileHash $dest -Algorithm SHA256).Hash
            if ($sourceHash -eq $destHash) {
                Write-Host "SKIP identical workflow: $($source.Name)"
                continue
            }

            if ($ConflictAction -eq 'Stop') {
                throw "Workflow conflict: $dest differs from repository source. Use -ConflictAction Backup to preserve the current file."
            }

            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $backupName = ([System.IO.Path]::GetFileNameWithoutExtension($dest)) + ".backup-$timestamp.json"
            $backup = Join-Path $destRoot $backupName
            if (Test-Path $backup) {
                $backupName = ([System.IO.Path]::GetFileNameWithoutExtension($dest)) + ".backup-$timestamp-$([guid]::NewGuid().ToString('N').Substring(0,8)).json"
                $backup = Join-Path $destRoot $backupName
            }
            if ($PSCmdlet.ShouldProcess($dest, "backup to $backup")) {
                Copy-Item $dest $backup -Force
                Write-Host "BACKUP $dest -> $backup"
            }
        }

        if ($PSCmdlet.ShouldProcess($dest, "copy workflow from $($source.FullName)")) {
            Copy-Item $source.FullName $dest -Force
            Write-Host "COPIED $($source.Name) -> $dest"
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Install-HermesWorkflows -ComfyRoot $ComfyRoot -Workflow $Workflow -Destination $Destination -ConflictAction $ConflictAction -RepositoryRoot $RepositoryRoot -WhatIf:$WhatIfPreference
}
