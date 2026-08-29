[CmdletBinding()]
param(
    [Alias('ComfyRoot')][string]$RequestedComfyRoot
)

$ErrorActionPreference = 'Stop'

function Resolve-HermesComfyLayout {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root)

    $rootFull = [System.IO.Path]::GetFullPath($Root)
    $layoutCandidates = @(
        $rootFull,
        (Join-Path $rootFull 'ComfyUI'),
        (Join-Path $rootFull 'resources\ComfyUI'),
        (Join-Path $rootFull 'resources\app\ComfyUI'),
        (Join-Path $rootFull 'app\ComfyUI')
    ) | Select-Object -Unique

    $valid = @()
    foreach ($candidate in $layoutCandidates) {
        if ((Test-Path (Join-Path $candidate 'custom_nodes') -PathType Container) -and
            (Test-Path (Join-Path $candidate 'models') -PathType Container)) {
            $valid += [System.IO.Path]::GetFullPath($candidate)
        }
    }

    return @($valid | Select-Object -Unique)
}

function Get-HermesNvidiaInfo {
    $command = Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue
    if (-not $command) {
        return [pscustomobject]@{ gpu = $null; vram_mb = $null; gpu_all = @() }
    }

    try {
        $lines = & $command.Source '--query-gpu=name,memory.total' '--format=csv,noheader,nounits' 2>$null
        $items = @()
        foreach ($line in @($lines)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line -split ',', 2
            if ($parts.Count -ne 2) { continue }
            $items += [pscustomobject]@{
                name = $parts[0].Trim()
                vram_mb = [int][double]($parts[1].Trim())
            }
        }
        if ($items.Count -eq 0) {
            return [pscustomobject]@{ gpu = $null; vram_mb = $null; gpu_all = @() }
        }
        return [pscustomobject]@{
            gpu = $items[0].name
            vram_mb = $items[0].vram_mb
            gpu_all = $items
        }
    } catch {
        return [pscustomobject]@{ gpu = $null; vram_mb = $null; gpu_all = @() }
    }
}

function Get-HermesSystemRamMb {
    try {
        $system = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        return [int][math]::Round([double]$system.TotalPhysicalMemory / 1MB)
    } catch {
        return $null
    }
}

function Get-HermesComfySystemInfo {
    [CmdletBinding()]
    param([string]$ComfyRoot)

    $candidateRoots = New-Object System.Collections.Generic.List[string]

    if ($ComfyRoot) {
        if (Test-Path $ComfyRoot -PathType Container) {
            foreach ($resolved in @(Resolve-HermesComfyLayout -Root $ComfyRoot)) {
                if (-not $candidateRoots.Contains($resolved)) { $candidateRoots.Add($resolved) }
            }
        }
    } else {
        $rawCandidates = @()
        if ($env:LOCALAPPDATA) {
            $rawCandidates += (Join-Path $env:LOCALAPPDATA 'Programs\ComfyUI')
            $rawCandidates += (Join-Path $env:LOCALAPPDATA 'Programs\comfyui-electron')
            $rawCandidates += (Join-Path $env:LOCALAPPDATA 'ComfyUI')
        }
        if ($env:APPDATA) {
            $rawCandidates += (Join-Path $env:APPDATA 'ComfyUI')
        }
        if ($env:USERPROFILE) {
            $rawCandidates += (Join-Path $env:USERPROFILE 'ComfyUI')
            $rawCandidates += (Join-Path $env:USERPROFILE 'Documents\ComfyUI')
            $rawCandidates += (Join-Path $env:USERPROFILE 'Desktop\ComfyUI')
        }

        foreach ($raw in @($rawCandidates | Select-Object -Unique)) {
            if (-not (Test-Path $raw -PathType Container)) { continue }
            foreach ($resolved in @(Resolve-HermesComfyLayout -Root $raw)) {
                if (-not $candidateRoots.Contains($resolved)) { $candidateRoots.Add($resolved) }
            }
        }
    }

    $resolvedRoot = $null
    if ($candidateRoots.Count -eq 1) {
        $resolvedRoot = $candidateRoots[0]
    }

    $nvidia = Get-HermesNvidiaInfo
    $gitAvailable = [bool](Get-Command 'git' -ErrorAction SilentlyContinue)

    [pscustomobject]@{
        windows = [System.Environment]::OSVersion.VersionString
        powershell = $PSVersionTable.PSVersion.ToString()
        gpu = $nvidia.gpu
        vram_mb = $nvidia.vram_mb
        gpu_all = $nvidia.gpu_all
        ram_mb = Get-HermesSystemRamMb
        git_available = $gitAvailable
        comfy_candidates = @($candidateRoots)
        resolved_comfy_root = $resolvedRoot
        custom_nodes_path = if ($resolvedRoot) { Join-Path $resolvedRoot 'custom_nodes' } else { $null }
        models_path = if ($resolvedRoot) { Join-Path $resolvedRoot 'models' } else { $null }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Get-HermesComfySystemInfo -ComfyRoot $RequestedComfyRoot | ConvertTo-Json -Depth 6
}
