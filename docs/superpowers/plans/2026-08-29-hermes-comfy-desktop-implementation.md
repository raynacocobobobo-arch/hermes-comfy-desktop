# Hermes Comfy Desktop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone, local-first Comfy Desktop execution layer that translates the Hermes digital-human reference-role contract into a safe SDXL-based single-image workflow first, then a sequential three-shot workflow for an RTX 4060 8 GB / 16 GB RAM Windows machine.

**Architecture:** `skills-share` remains the external policy source; this repository owns only local execution tooling, configuration, workflows, validation, and Codex instructions. The implementation uses explicit asset slots (`face`, `body`, `wardrobe`, `pose`, `scene`), read-only discovery before mutation, safe custom-node installation, and single-shot acceptance before three-shot production. Workflow JSON that depends on actual custom-node class names must be finalized only after Codex verifies the installed Comfy Desktop environment and current upstream node compatibility.

**Tech Stack:** Windows PowerShell 7+, Git, Comfy Desktop, SDXL, identity-aware conditioning (InstantID-class or verified equivalent), IPAdapter-class reference conditioning, DWPose/OpenPose-class pose preprocessing, SDXL pose ControlNet, JSON, JSON-compatible YAML, Markdown.

**Spec:** `docs/superpowers/specs/2026-08-29-hermes-comfy-desktop-design.md`

## Global Constraints

- Target host: Windows desktop, NVIDIA RTX 4060 8 GB VRAM, 16 GB system RAM.
- This repository is not a Hermes skill and must not modify any Hermes skill registry.
- `skills-share` is policy-only; no generated image or local model binary is written back into the skill repository.
- V1 baseline is SDXL; heavy FLUX-class workflows are not the default path.
- First-pass target is approximately `768x1024` for 3:4.
- Single-shot validation must pass before triple-shot production is enabled.
- Triple-shot execution is sequential; do not keep three full sampler branches resident on 8 GB VRAM.
- `face` is the only facial identity authority.
- `body`, `wardrobe`, `pose`, and `scene` must never redefine identity.
- Generated candidates must not become upstream identity references.
- Scripts must stop rather than guess when Comfy Desktop root resolution or destructive filesystem intent is ambiguous.
- Installation scripts must not force-reset unrelated repositories, delete unknown nodes, overwrite unknown model files, or auto-download multi-GB model weights.
- Large model binaries and user identity assets must never be committed to this repository.

---

## File Map

| File | Responsibility |
|---|---|
| `README.md` | Top-level operator entry point and install order |
| `config/asset-role-map.yaml` | Machine-readable five-slot Hermes role mapping |
| `config/node-list.json` | Required/optional custom-node package metadata |
| `config/model-recommendations.yaml` | Model-family metadata and destination guidance |
| `docs/setup-windows-rtx4060.md` | Hardware-specific setup and memory guidance |
| `docs/workflow-design.md` | Concrete execution graph and conditioning boundaries |
| `docs/codex-local-runbook.md` | Exact Codex local install/verify sequence |
| `docs/troubleshooting.md` | Evidence-driven failure diagnosis |
| `scripts/collect-system-info.ps1` | Read-only Windows/Comfy discovery |
| `scripts/bootstrap-comfy.ps1` | Safe custom-node bootstrap |
| `scripts/validate-comfy-env.ps1` | Read-only environment validator |
| `scripts/link-workflows.ps1` | Conflict-safe workflow copy/install |
| `templates/shot-contract-template.md` | Human/agent shot input contract |
| `templates/generation-checklist.md` | Hermes identity/role QC checklist |
| `workflows/hermes-dh-v1-single.json` | Canonical single-shot Comfy workflow export |
| `workflows/hermes-dh-v1-triple.json` | Canonical sequential three-shot task representation |
| `workflows/workflow-notes.md` | Node compatibility, weights, VRAM notes, limitations |
| `tests/validate-config.ps1` | Repository config/schema validation |
| `tests/validate-repo.ps1` | Repo completeness, binary/asset guard, workflow validation |

`*.yaml` files use JSON object syntax. JSON is valid YAML, and this lets validation use PowerShell `ConvertFrom-Json` without adding a YAML parser dependency.

---

### Task 1: Repository contract, config schema, and top-level documentation

**Files:**
- Create: `README.md`
- Create: `config/asset-role-map.yaml`
- Create: `config/node-list.json`
- Create: `config/model-recommendations.yaml`
- Create: `docs/setup-windows-rtx4060.md`
- Create: `templates/shot-contract-template.md`
- Create: `templates/generation-checklist.md`
- Create: `tests/validate-config.ps1`

**Interfaces:**
- Consumes: approved design spec.
- Produces: stable config keys used by every later script: `schema_version`, `slots`, `nodes`, `models`; stable slot names `face`, `body`, `wardrobe`, `pose`, `scene`.

- [ ] **Step 1: Write the failing config validator**

Create `tests/validate-config.ps1` with checks that:

```powershell
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

if ($roles.slots.face.hermes_role -ne 'IDENTITY ONLY') { throw 'face role mismatch' }
if ($roles.slots.body.hermes_role -ne 'BODY ONLY') { throw 'body role mismatch' }
if ($roles.slots.wardrobe.hermes_role -ne 'WARDROBE ONLY') { throw 'wardrobe role mismatch' }
if ($roles.slots.pose.hermes_role -ne 'POSE ONLY') { throw 'pose role mismatch' }
if ($roles.slots.scene.hermes_role -ne 'SCENE ONLY') { throw 'scene role mismatch' }

if (-not $nodes.nodes) { throw 'node-list.json has no nodes array' }
if (-not $models.models) { throw 'model-recommendations.yaml has no models array' }

Write-Host 'PASS config validation'
```

- [ ] **Step 2: Run validator and confirm failure**

Run:

```powershell
pwsh -NoProfile -File tests/validate-config.ps1
```

Expected: FAIL because config files do not yet exist.

- [ ] **Step 3: Create the role map with exact slot semantics**

Create `config/asset-role-map.yaml` as JSON-compatible YAML:

```json
{
  "schema_version": 1,
  "policy_source": "raynacocobobobo-arch/skills-share/plugins/hermes-skills/skills/hermes-creative-digital-human",
  "slots": {
    "face": {"hermes_role":"IDENTITY ONLY","priority":"CRITICAL","backend_strategy":"identity_conditioning","may_define_identity":true},
    "body": {"hermes_role":"BODY ONLY","priority":"HIGH","backend_strategy":"reference_low_strength","may_define_identity":false},
    "wardrobe": {"hermes_role":"WARDROBE ONLY","priority":"NORMAL","backend_strategy":"reference_appearance","may_define_identity":false},
    "pose": {"hermes_role":"POSE ONLY","priority":"NORMAL","backend_strategy":"pose_controlnet","may_define_identity":false},
    "scene": {"hermes_role":"SCENE ONLY","priority":"NORMAL","backend_strategy":"reference_scene","may_define_identity":false}
  }
}
```

- [ ] **Step 4: Create node and model metadata**

`config/node-list.json` must use this shape:

```json
{
  "schema_version": 1,
  "nodes": [
    {"id":"identity","required_for":["single","triple"],"purpose":"identity-aware SDXL conditioning","repository_candidates":["InstantID-class maintained Comfy package"],"resolved_repository":null},
    {"id":"reference_adapter","required_for":["single","triple"],"purpose":"non-identity body/wardrobe/scene reference conditioning","repository_candidates":["IPAdapter-class maintained Comfy package"],"resolved_repository":null},
    {"id":"pose_preprocessor","required_for":["single","triple"],"purpose":"DWPose/OpenPose extraction","repository_candidates":["controlnet-aux maintained Comfy package"],"resolved_repository":null},
    {"id":"face_detail","required_for":[],"purpose":"optional localized face-detail pass","repository_candidates":["Impact-Pack-class maintained Comfy package"],"resolved_repository":null}
  ]
}
```

`resolved_repository` stays `null` until Codex verifies current upstream compatibility on the target machine; bootstrap must refuse unresolved required packages instead of guessing.

`config/model-recommendations.yaml` must use JSON-compatible YAML with entries for: `sdxl_checkpoint`, `identity_model`, `clip_vision_adapter`, `pose_controlnet_sdxl`, `pose_preprocessor` and fields `required`, `expected_folder`, `selection_rule`, `resolved_filename`.

- [ ] **Step 5: Write README/setup/templates around the fixed schema**

`README.md` must state the exact install order: discover → resolve packages/models → validate → install single workflow → smoke test → enable triple workflow.

`docs/setup-windows-rtx4060.md` must set the first test target to approximately `768x1024`, one candidate at a time, and explain that three-shot production is sequential.

`templates/shot-contract-template.md` must expose explicit fields for `character_token`, five asset slots, `ratio`, `shot_id`, `framing`, `camera_angle`, `action`, `prompt_suffix`, and `seed`.

`templates/generation-checklist.md` must check identity first, then body perspective, pose, wardrobe contamination, scene perspective/lighting, and classify `APPROVED`, `FACE_REPAIR`, or `REGENERATE`.

- [ ] **Step 6: Run config validator**

Run:

```powershell
pwsh -NoProfile -File tests/validate-config.ps1
```

Expected: `PASS config validation`.

- [ ] **Step 7: Commit**

```bash
git add README.md config docs/setup-windows-rtx4060.md templates tests/validate-config.ps1
git commit -m "feat: define Hermes Comfy repository contract"
```

---

### Task 2: Read-only Comfy Desktop and hardware discovery

**Files:**
- Create: `scripts/collect-system-info.ps1`
- Create: `tests/test-collect-system-info.ps1`

**Interfaces:**
- Consumes: optional `-ComfyRoot` string.
- Produces: one PowerShell object with `windows`, `powershell`, `gpu`, `vram_mb`, `ram_mb`, `git_available`, `comfy_candidates`, `resolved_comfy_root`, `custom_nodes_path`, `models_path`.

- [ ] **Step 1: Write failing discovery tests**

Create `tests/test-collect-system-info.ps1` that dot-sources the script and asserts:

```powershell
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $RepoRoot 'scripts/collect-system-info.ps1')

$temp = Join-Path $env:TEMP ('hermes-comfy-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $temp 'custom_nodes') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $temp 'models') -Force | Out-Null
try {
    $result = Get-HermesComfySystemInfo -ComfyRoot $temp
    if ($result.resolved_comfy_root -ne $temp) { throw 'explicit root not preserved' }
    if (-not $result.custom_nodes_path.EndsWith('custom_nodes')) { throw 'custom_nodes path missing' }
    if (-not $result.models_path.EndsWith('models')) { throw 'models path missing' }
} finally {
    Remove-Item $temp -Recurse -Force
}
Write-Host 'PASS system-info tests'
```

- [ ] **Step 2: Run and confirm failure**

```powershell
pwsh -NoProfile -File tests/test-collect-system-info.ps1
```

Expected: FAIL because `Get-HermesComfySystemInfo` does not exist.

- [ ] **Step 3: Implement discovery function**

`scripts/collect-system-info.ps1` must define:

```powershell
function Get-HermesComfySystemInfo {
    [CmdletBinding()]
    param([string]$ComfyRoot)
    # return [pscustomobject] with the interface above
}
```

Behavior:

- explicit `-ComfyRoot` wins if it exists and contains or can resolve `custom_nodes` and `models`;
- otherwise scan a small documented candidate set under `$env:LOCALAPPDATA`, `$env:APPDATA`, `$env:USERPROFILE`, and common Desktop install locations;
- never pick one candidate when more than one viable root is found; return all candidates and leave `resolved_comfy_root` null;
- GPU/VRAM use `nvidia-smi` if available; RAM uses `Get-CimInstance Win32_ComputerSystem`;
- function performs no filesystem mutation except ordinary read operations.

When run as a script, print JSON with:

```powershell
Get-HermesComfySystemInfo -ComfyRoot $ComfyRoot | ConvertTo-Json -Depth 5
```

- [ ] **Step 4: Run tests**

```powershell
pwsh -NoProfile -File tests/test-collect-system-info.ps1
```

Expected: `PASS system-info tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/collect-system-info.ps1 tests/test-collect-system-info.ps1
git commit -m "feat: add read-only Comfy environment discovery"
```

---

### Task 3: Safe environment validator and repository guardrails

**Files:**
- Create: `scripts/validate-comfy-env.ps1`
- Create: `tests/validate-repo.ps1`
- Create: `tests/test-validate-comfy-env.ps1`

**Interfaces:**
- Consumes: `-ComfyRoot`, config files, workflow files.
- Produces: compact result lines prefixed `PASS`, `WARN`, or `FAIL`; exit `0` only when required checks pass.

- [ ] **Step 1: Write failing validator tests**

Create a temporary fake Comfy root with `custom_nodes` and `models` and assert that unresolved required node repositories produce `FAIL`, while an optional node absence produces only `WARN`.

Use subprocess execution and `$LASTEXITCODE` so the test verifies process exit semantics, not just printed text.

- [ ] **Step 2: Implement `validate-comfy-env.ps1`**

Required checks:

```text
PASS: explicit/resolved Comfy root exists
PASS: custom_nodes path exists
PASS: models path exists
FAIL: required node package is unresolved in node-list.json
FAIL: required resolved node directory does not exist
WARN: optional node directory missing
FAIL: workflow JSON cannot parse
FAIL: workflow JSON contains string marker __UNRESOLVED_NODE_CLASS__
PASS/WARN: disk free space is reported or diagnostic is unavailable
```

The validator must never install or alter files.

- [ ] **Step 3: Implement repository validator**

`tests/validate-repo.ps1` must:

- invoke `tests/validate-config.ps1`;
- parse every `workflows/*.json` that exists;
- reject files over 10 MB unless under `docs/`;
- reject common model extensions anywhere in git worktree: `.safetensors`, `.ckpt`, `.pt`, `.pth`, `.bin`;
- reject image assets under directories named `identity`, `face`, or `body` in the repository;
- ensure all required paths from the spec exist once Task 6 finishes.

The binary guard command may use:

```powershell
$forbidden = Get-ChildItem $RepoRoot -Recurse -File | Where-Object {
    $_.Extension -in @('.safetensors','.ckpt','.pt','.pth','.bin')
}
if ($forbidden) { throw "Forbidden model binary committed: $($forbidden.FullName -join ', ')" }
```

- [ ] **Step 4: Run tests**

```powershell
pwsh -NoProfile -File tests/test-validate-comfy-env.ps1
pwsh -NoProfile -File tests/validate-repo.ps1 -AllowIncompleteWorkflows
```

Expected: both pass for the current implementation stage.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-comfy-env.ps1 tests
git commit -m "feat: add environment and repository validation"
```

---

### Task 4: Safe node bootstrap and workflow installation tooling

**Files:**
- Create: `scripts/bootstrap-comfy.ps1`
- Create: `scripts/link-workflows.ps1`
- Create: `tests/test-bootstrap-comfy.ps1`
- Create: `tests/test-link-workflows.ps1`
- Create: `docs/codex-local-runbook.md`

**Interfaces:**
- `bootstrap-comfy.ps1`: consumes explicit `-ComfyRoot` and `config/node-list.json`; clones only entries with non-null `resolved_repository`.
- `link-workflows.ps1`: consumes `-ComfyRoot`, optional `-Destination`, and `-ConflictAction Stop|Backup`; copies known workflow files only.

- [ ] **Step 1: Write bootstrap safety tests**

Tests must verify:

- missing `git` causes failure before clone;
- required node with `resolved_repository: null` causes failure;
- existing directory without `.git` causes failure;
- existing git repository whose `origin` differs from configured remote causes failure;
- matching existing repository is skipped, not reset or deleted.

Use temporary directories and a temporary synthetic `node-list.json`; do not hit the network in tests.

- [ ] **Step 2: Implement bootstrap**

Core algorithm:

```text
resolve explicit Comfy root
load node-list.json
for each node required for requested mode:
  if resolved_repository is null -> FAIL
  expected folder = custom_nodes/<configured folder_name>
  if missing -> git clone <resolved_repository> <expected folder>
  if existing non-git -> FAIL
  if existing git origin != expected -> FAIL
  if existing git origin matches -> SKIP
never git reset --hard
never git clean
never remove unrelated directories
never download model weights
```

Support `-WhatIf` through `SupportsShouldProcess`.

- [ ] **Step 3: Write workflow-copy safety tests**

Create a fake workflow destination and verify:

- identical destination is skipped;
- different destination with default `Stop` fails;
- `-ConflictAction Backup` creates `<name>.backup-YYYYMMDD-HHMMSS.json` before copying;
- only `workflows/hermes-dh-v1-single.json` and `workflows/hermes-dh-v1-triple.json` are eligible.

- [ ] **Step 4: Implement `link-workflows.ps1`**

Default is copy. Do not create symlinks unless a future explicit feature changes the spec.

- [ ] **Step 5: Write Codex runbook**

`docs/codex-local-runbook.md` must contain exact phases:

```text
A. Pull repo and read spec
B. Run collect-system-info.ps1
C. Resolve actual Comfy root; stop on ambiguity
D. Inspect Comfy version/startup logs and current custom-node compatibility
E. Resolve node-list.json repository URLs/folder names only after verification
F. Identify required model files and exact model folders; ask user before multi-GB downloads
G. Run bootstrap-comfy.ps1
H. Restart Comfy Desktop and inspect node load errors
I. Run validate-comfy-env.ps1
J. Finalize/open single workflow
K. Execute one user-supplied five-slot smoke test
L. Record identity result as human-gated
M. Only then finalize/enable triple workflow
```

Include explicit prohibition on editing `skills-share` registry.

- [ ] **Step 6: Run tests**

```powershell
pwsh -NoProfile -File tests/test-bootstrap-comfy.ps1
pwsh -NoProfile -File tests/test-link-workflows.ps1
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add scripts/bootstrap-comfy.ps1 scripts/link-workflows.ps1 tests/test-bootstrap-comfy.ps1 tests/test-link-workflows.ps1 docs/codex-local-runbook.md
git commit -m "feat: add safe Comfy bootstrap and workflow install tooling"
```

---

### Task 5: Resolve current Comfy node/model compatibility on the target Windows machine

**Files:**
- Modify: `config/node-list.json`
- Modify: `config/model-recommendations.yaml`
- Create: `docs/workflow-design.md`
- Create: `docs/troubleshooting.md`

**Interfaces:**
- Consumes: real Comfy Desktop root, version/startup output, current upstream documentation, machine VRAM/RAM report.
- Produces: concrete `resolved_repository`, `folder_name`, required model filenames/folders, verified node class names used by Task 6.

- [ ] **Step 1: Collect evidence before changing config**

On the Windows machine run:

```powershell
pwsh -NoProfile -File scripts/collect-system-info.ps1 -ComfyRoot '<actual-root>'
```

Then inspect Comfy Desktop's actual `custom_nodes`, `models`, installed version/build information, and startup log. Record the discovered paths in the Codex response; do not commit machine-specific absolute paths.

- [ ] **Step 2: Verify current upstream packages**

For each conceptual package in `node-list.json`, Codex must verify current maintained repository, installation instructions, supported Comfy version, and exact node class names needed by the graph. The selected set must provide:

```text
identity-aware SDXL conditioning
IPAdapter/reference conditioning
DWPose/OpenPose preprocessing
SDXL pose ControlNet support
optional localized face-detail path
```

If a package conflicts with the installed Comfy Desktop runtime or Python environment, choose a maintained compatible equivalent and document the reason in `docs/workflow-design.md`.

- [ ] **Step 3: Resolve config**

Update each required node entry from `resolved_repository: null` to a concrete repository URL plus `folder_name`. Update model metadata with exact `resolved_filename` only after verifying the chosen node package documentation.

No model file itself is committed.

- [ ] **Step 4: Write concrete workflow design**

`docs/workflow-design.md` must list exact node class names and graph order for:

```text
checkpoint/text conditioning
face identity path
body non-identity reference path
wardrobe non-identity reference path
scene non-identity reference path
pose preprocessor + pose ControlNet
sampler/decode/save
optional post-generation face detail
```

It must also document 8 GB-safe starting parameters and which controls are intentionally weakened or staged if simultaneous adapters exceed VRAM.

- [ ] **Step 5: Write evidence-driven troubleshooting**

`docs/troubleshooting.md` must map symptoms to checks, including:

```text
missing node at workflow load -> inspect startup log and package folder/origin
CUDA OOM -> reduce resolution/reference stack, keep single-shot, disable optional detail pass
face drift -> verify face slot reaches identity node; reduce non-identity contamination; do not promote candidate
pose ignored -> inspect preprocessor output and ControlNet model compatibility
wardrobe reference changes face -> reduce/non-stage adapter influence; face remains sole identity authority
scene perspective wrong -> lower scene reference dominance or regenerate with corrected camera/pose contract
```

- [ ] **Step 6: Validate resolved environment**

```powershell
pwsh -NoProfile -File scripts/validate-comfy-env.ps1 -ComfyRoot '<actual-root>'
```

Expected: no unresolved required package failure. Missing model files may remain explicit FAIL until user-approved downloads complete.

- [ ] **Step 7: Commit**

```bash
git add config docs/workflow-design.md docs/troubleshooting.md
git commit -m "feat: resolve target Comfy node and model compatibility"
```

---

### Task 6: Build and validate the single-shot workflow

**Files:**
- Create: `workflows/hermes-dh-v1-single.json`
- Create: `workflows/workflow-notes.md`
- Modify: `tests/validate-repo.ps1`

**Interfaces:**
- Consumes: exact node class names and model filenames from Task 5.
- Produces: a Comfy Desktop workflow that exposes five explicit image slots and one shot contract, generates one candidate, and saves downstream output only.

- [ ] **Step 1: Create a failing repository check for the workflow**

Remove the `-AllowIncompleteWorkflows` bypass for `hermes-dh-v1-single.json` and make `tests/validate-repo.ps1` require:

```text
valid JSON
no __UNRESOLVED_NODE_CLASS__ marker
all five semantic slot labels present in workflow metadata/notes
one output save path
no reference from output image back into face/identity input
```

- [ ] **Step 2: Build the graph in the actual Comfy Desktop UI/runtime**

Using only the verified node classes from Task 5, construct the single workflow with explicit groups/labels:

```text
FACE — IDENTITY ONLY | CRITICAL
BODY — BODY ONLY | HIGH
WARDROBE — WARDROBE ONLY | NORMAL
POSE — POSE ONLY | NORMAL
SCENE — SCENE ONLY | NORMAL
SHOT CONTRACT
SAMPLING
OUTPUT
```

Export the workflow JSON from Comfy Desktop; do not hand-invent undocumented node IDs or socket signatures.

- [ ] **Step 3: Set 4060-safe first-pass defaults**

Start around `768x1024`, batch size `1`, one sampler path, pose as the only mandatory ControlNet, and optional face detail disabled by default. If the selected checkpoint/sampler requires different proven stable values, document them in `workflow-notes.md` with the observed reason.

- [ ] **Step 4: Run repository validation**

```powershell
pwsh -NoProfile -File tests/validate-repo.ps1 -AllowMissingTripleWorkflow
```

Expected: PASS single-workflow structural checks.

- [ ] **Step 5: Install/open workflow locally**

```powershell
pwsh -NoProfile -File scripts/link-workflows.ps1 -ComfyRoot '<actual-root>' -Workflow single
```

Open in Comfy Desktop and confirm no missing-node errors.

- [ ] **Step 6: Execute the single-image smoke test**

Use user-provided approved assets in their explicit slots. Generate exactly one 3:4 candidate. Record:

```text
runtime success/failure
peak VRAM if available
identity result: human PASS/FAIL
pose result
wardrobe contamination result
scene perspective result
```

If identity fails, do not proceed to triple workflow merely because runtime succeeded.

- [ ] **Step 7: Commit after runtime and human gate pass**

```bash
git add workflows/hermes-dh-v1-single.json workflows/workflow-notes.md tests/validate-repo.ps1
git commit -m "feat: add validated Hermes single-shot Comfy workflow"
```

---

### Task 7: Add sequential three-shot production

**Files:**
- Create: `workflows/hermes-dh-v1-triple.json`
- Modify: `workflows/workflow-notes.md`
- Modify: `README.md`
- Modify: `tests/validate-repo.ps1`

**Interfaces:**
- Consumes: accepted single-shot workflow and shared upstream asset set.
- Produces: one task package representing three explicit shot contracts executed sequentially, each with independent pose/prompt/seed.

- [ ] **Step 1: Define three-shot task semantics in notes**

Document the required shape:

```text
shared: face + body + wardrobe + scene
shot01: pose01 + prompt01 + seed01 + framing01
shot02: pose02 + prompt02 + seed02 + framing02
shot03: pose03 + prompt03 + seed03 + framing03
execution: sequential
```

- [ ] **Step 2: Implement the least-resident sequential mechanism supported by the real Comfy environment**

Preferred order:

1. one reusable graph plus queue/submission helper semantics if supported;
2. otherwise a workflow/task JSON that stores three shot configurations but submits one sampler execution at a time;
3. do not implement three simultaneous full sampler branches on the 8 GB target.

Export or generate only through documented Comfy APIs/runtime behavior verified locally.

- [ ] **Step 3: Extend repository validation**

Require `hermes-dh-v1-triple.json` to parse and contain three distinct shot identifiers. Reject any design marker declaring `parallel_full_sampler_branches: true`.

- [ ] **Step 4: Run three-shot local acceptance**

Use the same approved face/body/wardrobe/scene references and three explicit pose/shot contracts. Queue three shots sequentially. Confirm:

```text
all three complete without intentional simultaneous full-branch residency
three distinct output filenames
independent seed/prompt/pose values
no candidate is reused as identity input for another shot
human identity gate evaluated per output
```

- [ ] **Step 5: Update README production instructions**

README must now distinguish:

```text
Single-shot validation mode
Three-shot production mode
FACE_REPAIR remains a later/narrow recovery path, not default generation
```

- [ ] **Step 6: Run full repository validation**

```powershell
pwsh -NoProfile -File tests/validate-config.ps1
pwsh -NoProfile -File tests/validate-repo.ps1
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add workflows README.md tests/validate-repo.ps1
git commit -m "feat: add sequential three-shot Hermes production workflow"
```

---

### Task 8: Final verification and Codex handoff

**Files:**
- Modify: `docs/codex-local-runbook.md`
- Modify: `docs/troubleshooting.md`

**Interfaces:**
- Consumes: completed repository and local runtime evidence.
- Produces: a reproducible final handoff that another Codex session can execute without conversation history.

- [ ] **Step 1: Run every repository test**

```powershell
pwsh -NoProfile -File tests/validate-config.ps1
pwsh -NoProfile -File tests/test-collect-system-info.ps1
pwsh -NoProfile -File tests/test-validate-comfy-env.ps1
pwsh -NoProfile -File tests/test-bootstrap-comfy.ps1
pwsh -NoProfile -File tests/test-link-workflows.ps1
pwsh -NoProfile -File tests/validate-repo.ps1
```

Expected: all PASS.

- [ ] **Step 2: Run final target-machine validation**

```powershell
pwsh -NoProfile -File scripts/validate-comfy-env.ps1 -ComfyRoot '<actual-root>'
```

Expected: required components PASS; optional components may WARN.

- [ ] **Step 3: Verify Git hygiene**

```bash
git status --short
git ls-files | grep -Ei '\.(safetensors|ckpt|pt|pth|bin)$' && exit 1 || true
```

Expected: clean tree; no model binaries committed.

- [ ] **Step 4: Update runbook with exact verified package names and workflow open path**

Do not add machine-specific absolute paths. Record only package identities, required model filenames/folders, workflow names, and the sequence Codex should use on another Windows machine.

- [ ] **Step 5: Commit final docs**

```bash
git add docs/codex-local-runbook.md docs/troubleshooting.md
git commit -m "docs: finalize Hermes Comfy Desktop local handoff"
```

- [ ] **Step 6: Final completion evidence**

Before claiming completion, capture and report:

```text
repository test results
Comfy environment validator result
single-shot runtime result + human identity gate result
three-shot runtime result + per-shot identity gate result
git status
final commit SHA
```

A runtime-successful image is not an identity PASS unless the user explicitly approves likeness.
