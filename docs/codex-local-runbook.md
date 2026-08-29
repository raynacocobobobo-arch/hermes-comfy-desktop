# Codex Local Runbook — Hermes Comfy Desktop

This runbook is for Codex running on the target Windows machine with Comfy Desktop installed.

## Non-negotiable rules

- This repository is not a Hermes skill.
- Do **not** edit `skills-share/manifests/skill-registry.json`.
- Read the current digital-human policy from `skills-share`, but keep all Comfy execution files in `hermes-comfy-desktop`.
- Do not force-reset, `git clean`, delete, or overwrite unrelated custom-node repositories.
- Do not overwrite unknown model files.
- Do not auto-download multi-GB model weights without explicit user approval.
- Do not guess the Comfy root when discovery is ambiguous.
- Do not hand-invent undocumented Comfy node class names or socket signatures.
- Do not claim identity PASS until the user approves likeness.

## A. Pull repository and read the contract

Until PR #1 is merged, the executable repository-side tooling lives on `feat/implement-local-adapter`. Codex must use that branch for the local installation phase.

Fresh clone:

```powershell
git clone https://github.com/raynacocobobobo-arch/hermes-comfy-desktop.git
cd hermes-comfy-desktop
git fetch origin
git switch feat/implement-local-adapter
git pull --ff-only origin feat/implement-local-adapter
```

If already cloned:

```powershell
git fetch origin
git switch feat/implement-local-adapter
git pull --ff-only origin feat/implement-local-adapter
```

Confirm before doing anything else:

```powershell
git branch --show-current
git status --short
```

Expected branch: `feat/implement-local-adapter`. Stop if the working tree contains unrelated local changes that would be overwritten.

Read, in order:

1. `docs/superpowers/specs/2026-08-29-hermes-comfy-desktop-design.md`
2. `docs/superpowers/plans/2026-08-29-hermes-comfy-desktop-implementation.md`
3. `README.md`
4. the current `hermes-creative-digital-human/SKILL.md` in `skills-share`

## B. Run read-only system discovery

First try automatic discovery:

```powershell
pwsh -NoProfile -File scripts/collect-system-info.ps1
```

If exactly one Comfy root is not resolved, inspect the reported candidates and the actual Comfy Desktop installation. Then rerun with the explicit root:

```powershell
pwsh -NoProfile -File scripts/collect-system-info.ps1 -ComfyRoot '<actual-comfy-root>'
```

Record in the Codex response, not in committed machine-specific config:

- Windows version
- GPU / VRAM
- system RAM
- resolved Comfy root
- `custom_nodes` path
- `models` path
- git availability

Stop if the root remains ambiguous.

## C. Inspect the real Comfy Desktop runtime

Before installing anything:

- identify Comfy Desktop version/build;
- inspect `custom_nodes` contents;
- inspect `models` subdirectories;
- start/restart Comfy Desktop once and capture startup output relevant to custom-node loading;
- note any existing identity, IPAdapter/reference, pose-preprocessor, ControlNet, and face-detail packages.

Do not infer successful node loading from folder presence alone.

## D. Verify current custom-node compatibility

For each conceptual entry in `config/node-list.json`, verify current upstream documentation/repository state against the installed Comfy runtime:

- identity-aware SDXL conditioning;
- non-identity IPAdapter/reference conditioning;
- DWPose/OpenPose preprocessing;
- optional localized face-detail support.

For the selected packages, record:

- exact repository URL;
- expected `custom_nodes` folder name;
- installation instructions/dependencies;
- exact node class names needed by the intended graph;
- any version/runtime incompatibility observed.

Candidate URLs in `node-list.json` are hints only. If a candidate is archived, incompatible, or superseded, choose a maintained compatible equivalent and document why.

Only after verification, update `resolved_repository` and `folder_name` locally.

## E. Resolve required model files

Using the verified node-package documentation, resolve `config/model-recommendations.yaml`:

- realistic SDXL checkpoint;
- identity-conditioning model files;
- CLIP Vision / reference-adapter weights;
- SDXL pose ControlNet;
- pose-preprocessor files/cache if required.

For each unresolved required model, show the user:

- exact filename;
- source;
- approximate download size when available;
- exact destination folder relative to the resolved Comfy root.

Ask before any multi-GB download. Do not commit model files.

## F. Run safe custom-node bootstrap

After `node-list.json` contains concrete compatible repositories/folder names:

```powershell
pwsh -NoProfile -File scripts/bootstrap-comfy.ps1 -ComfyRoot '<actual-comfy-root>' -Mode single -WhatIf
```

Review the dry-run. Then, with user approval if installation will occur:

```powershell
pwsh -NoProfile -File scripts/bootstrap-comfy.ps1 -ComfyRoot '<actual-comfy-root>' -Mode single
```

The script must stop on:

- unresolved required package;
- existing non-git target directory;
- existing git repository with mismatched origin.

It must skip a matching existing repository without resetting or cleaning it.

## G. Restart and inspect startup logs

Restart Comfy Desktop. Confirm the selected custom nodes actually load. Capture any import/dependency errors before editing workflows.

Do not continue to graph construction while required node classes are missing.

## H. Validate the resolved environment

```powershell
pwsh -NoProfile -File scripts/validate-comfy-env.ps1 -ComfyRoot '<actual-comfy-root>' -Mode single
```

Required packages and resolved model files must PASS. Optional packages may WARN.

If validation fails, diagnose the evidence before changing strategy.

## I. Finalize the concrete single-workflow design

Create/update `docs/workflow-design.md` with exact verified node class names and graph order for:

```text
checkpoint + text conditioning
FACE — IDENTITY ONLY | CRITICAL
BODY — BODY ONLY | HIGH
WARDROBE — WARDROBE ONLY | NORMAL
POSE — POSE ONLY | NORMAL
SCENE — SCENE ONLY | NORMAL
sampling / decode / save
optional post-generation face detail
```

The `face` slot must be the only identity authority. Body, wardrobe, pose, and scene paths must remain non-identity conditioning.

## J. Build/export the single workflow in Comfy Desktop

Build the graph in the **actual Comfy Desktop UI/runtime** using only verified node classes and sockets. Do not fabricate workflow JSON by hand.

Starting target for RTX 4060 8 GB:

- approximately 768x1024;
- batch size 1;
- one sampler path;
- pose as the only mandatory ControlNet;
- optional face-detail pass disabled initially;
- reduce/stage non-identity adapter influence if the combined stack causes OOM or identity contamination.

Export from Comfy Desktop as:

`workflows/hermes-dh-v1-single.json`

Then run repository validation:

```powershell
pwsh -NoProfile -File tests/validate-repo.ps1 -AllowMissingTripleWorkflow
```

## K. Install/open the single workflow and smoke test

Copy the workflow to the actual Comfy workflow destination. If auto-detection is ambiguous, provide it explicitly:

```powershell
pwsh -NoProfile -File scripts/link-workflows.ps1 `
  -ComfyRoot '<actual-comfy-root>' `
  -Destination '<actual-workflow-directory>' `
  -Workflow single
```

Load the workflow. Confirm no missing-node errors.

Use user-supplied approved assets in the explicit five slots and generate exactly one candidate.

Record:

```text
runtime: PASS/FAIL
peak VRAM: value if observable
identity: USER PASS/FAIL
pose: PASS/FAIL + note
wardrobe contamination: PASS/FAIL + note
scene perspective/lighting: PASS/FAIL + note
```

A runtime PASS is not an identity PASS.

## L. Stop on identity failure

If the user says the person does not look like the approved identity:

- mark the candidate failed for identity/reference reuse;
- do not use that candidate as the face input for another generation;
- inspect identity-node routing and non-identity contamination;
- adjust the single-shot strategy first;
- do not proceed to three-shot production merely because the graph ran.

## M. Enable three-shot production only after single-shot acceptance

Three-shot semantics:

```text
shared: face + body + wardrobe + scene
SHOT01: pose01 + prompt01 + seed01 + framing01
SHOT02: pose02 + prompt02 + seed02 + framing02
SHOT03: pose03 + prompt03 + seed03 + framing03
execution: sequential
```

Prefer the least-resident documented mechanism supported by the actual Comfy environment. Do not create three simultaneous full sampler branches on the 8 GB target.

Export/finalize:

`workflows/hermes-dh-v1-triple.json`

Run full repository validation after the triple path is real and tested:

```powershell
pwsh -NoProfile -File tests/validate-config.ps1
pwsh -NoProfile -File tests/test-collect-system-info.ps1
pwsh -NoProfile -File tests/test-validate-comfy-env.ps1
pwsh -NoProfile -File tests/test-bootstrap-comfy.ps1
pwsh -NoProfile -File tests/test-link-workflows.ps1
pwsh -NoProfile -File tests/validate-repo.ps1
```

## Required handoff evidence

When Codex finishes the local phase, report back:

- actual Comfy Desktop version/build;
- resolved Comfy root structure;
- selected custom-node package URLs + folder names;
- exact node class names used in the graph;
- resolved model filenames/folders;
- repository test output;
- `validate-comfy-env.ps1` output;
- single-shot runtime result and user identity verdict;
- triple-shot runtime results and per-shot user identity verdicts;
- git diff/status and commit SHA.

Do not include private identity images or model binaries in commits.
