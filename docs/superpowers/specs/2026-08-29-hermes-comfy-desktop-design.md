# Hermes Comfy Desktop Design

Date: 2026-08-29
Status: Approved design, pending implementation plan
Repository: `raynacocobobobo-arch/hermes-comfy-desktop`
Target host: Windows desktop, NVIDIA RTX 4060 8 GB VRAM, 16 GB system RAM
External policy source: `raynacocobobobo-arch/skills-share` → `plugins/hermes-skills/skills/hermes-creative-digital-human`

## 1. Goal

Build a standalone local Comfy Desktop execution layer for Hermes digital-human production. The new repository is **not a Hermes skill** and must not modify the skill registry. It consumes the rules defined by `hermes-creative-digital-human` and turns them into a reproducible local image-generation workflow without requiring OpenAI Image API spend.

The first release must support these explicit input slots:

- approved face / identity reference
- approved body reference
- wardrobe reference
- pose reference
- scene reference
- textual shot description

The first production milestone is one controlled 3:4 image. The second is a one-task/three-shot workflow where all three shots share the same upstream identity/body/wardrobe/scene assets while pose, prompt suffix, framing, and seed may differ per shot.

## 2. System boundary

Three systems remain separate:

1. `skills-share`: policy and Hermes production rules.
2. `hermes-comfy-desktop`: local adapter, configuration, install scripts, workflow files, validation, and Codex runbook.
3. Comfy Desktop: local image-generation runtime and model execution.

No files from this repository are to be registered as a new Hermes skill.

## 3. Core Hermes contract

The adapter preserves the reference-role contract from `hermes-creative-digital-human`:

| Slot | Hermes role | Intended Comfy responsibility | May define face identity? |
|---|---|---|---|
| `face` | `IDENTITY ONLY` | identity-aware conditioning | Yes |
| `body` | `BODY ONLY` | body/silhouette support | No |
| `wardrobe` | `WARDROBE ONLY` | clothing/appearance reference | No |
| `pose` | `POSE ONLY` | pose extraction + ControlNet | No |
| `scene` | `SCENE ONLY` | environment/composition reference | No |

The workflow must never infer a role from visual similarity. The operator places each image into an explicit named slot.

The star-topology rule is mandatory: every candidate starts from approved upstream identity/body assets. A generated candidate must not become the identity source for the next candidate.

## 4. Hardware-first constraints

The default implementation targets RTX 4060 8 GB VRAM and 16 GB RAM.

V1 constraints:

- SDXL-class realistic checkpoint as baseline model family.
- First-pass output target around `768x1024` for 3:4.
- Single-shot validation before three-shot production.
- Three-shot execution is sequential, not three full resident sampler branches.
- No heavy FLUX workflow as the default path.
- No default multi-ControlNet stack beyond the pose control required by V1.
- Optional face-detail pass occurs only after base generation.
- Scripts must detect the real Comfy Desktop location instead of hard-coding one Windows path.

## 5. Repository layout

```text
hermes-comfy-desktop/
├── README.md
├── config/
│   ├── asset-role-map.yaml
│   ├── node-list.json
│   └── model-recommendations.yaml
├── docs/
│   ├── setup-windows-rtx4060.md
│   ├── workflow-design.md
│   ├── codex-local-runbook.md
│   ├── troubleshooting.md
│   └── superpowers/
│       ├── specs/
│       └── plans/
├── scripts/
│   ├── collect-system-info.ps1
│   ├── bootstrap-comfy.ps1
│   ├── validate-comfy-env.ps1
│   └── link-workflows.ps1
├── templates/
│   ├── shot-contract-template.md
│   └── generation-checklist.md
├── workflows/
│   ├── hermes-dh-v1-single.json
│   ├── hermes-dh-v1-triple.json
│   └── workflow-notes.md
└── tests/
    ├── validate-config.ps1
    └── validate-repo.ps1
```

Large model binaries and user identity assets must not be committed to this repository.

## 6. V1 execution architecture

### 6.1 Identity path

`face` is the only facial identity authority. V1 should use a currently maintained identity-aware SDXL-compatible path, preferably InstantID-class or an equivalent supported by the installed Comfy environment. Exact node/package selection must be verified against the installed Comfy Desktop version before installation.

The workflow must label the path semantically as `IDENTITY ONLY | CRITICAL` and must not feed wardrobe, body, pose, or scene images into the identity-conditioning input.

### 6.2 Pose path

`pose` is processed by a DWPose/OpenPose-class preprocessor and then an SDXL-compatible pose ControlNet. The intended carrier is skeleton/pose geometry, not the reference person's face or appearance.

If pose extraction fails or produces implausible geometry, that shot is blocked until the pose is corrected or pose control is explicitly disabled.

### 6.3 Body, wardrobe, and scene paths

These are non-identity reference paths. V1 should use an IPAdapter-class/reference-adapter strategy where current compatibility allows:

- `body`: low-strength global body/silhouette support;
- `wardrobe`: appearance/clothing support;
- `scene`: environment/composition support.

Because 8 GB VRAM is the target, staged or simplified reference application is allowed. The adapter must report backend limitations rather than pretending exact garment transfer is guaranteed.

### 6.4 Prompt path

The textual shot description may control framing, camera angle, action details, lighting intent, realism language, and exclusions. Text never replaces the explicit identity reference.

### 6.5 Sampling/output

The single workflow generates one candidate at a time.

The triple workflow represents three explicit shot contracts, not `batch=3` random variations. For example:

```text
shared: face + body + wardrobe + scene
SHOT01: front medium-close, direct gaze, pose A
SHOT02: 45-degree medium, look toward poster, pose B
SHOT03: half-body candid turn, pose C
```

On 8 GB VRAM, these shots are queued sequentially. If Comfy's graph format makes sequential subjobs awkward inside one graph, the repository may use a queue helper or documented repeated submissions while preserving the user-facing concept of one task package with three explicit shots.

Output filenames must include a project/character token, workflow version, shot id, and seed or execution id. Outputs remain downstream content and are never automatically promoted into identity assets.

## 7. Required configuration files

### `config/asset-role-map.yaml`

A small machine-readable mapping, not a registry. It must map the five named slots to the Hermes roles and to backend strategies. Numeric weights belong to workflow implementation notes, not to the Hermes role contract.

### `config/node-list.json`

Declares required and optional custom-node packages, repository URLs/identities, purpose, and whether they are required for the single or triple workflow. Presence of a directory alone does not prove a node loaded successfully.

### `config/model-recommendations.yaml`

Declares model families, expected Comfy model categories/folders, and retrieval guidance. It stores metadata only, never model binaries.

Required categories include:

- realistic SDXL checkpoint;
- identity-conditioning model files for the chosen identity node;
- CLIP Vision/reference-adapter weights;
- SDXL pose ControlNet;
- pose-preprocessor model files if needed.

## 8. PowerShell scripts

All scripts should be idempotent where practical and must fail visibly rather than guessing.

### `collect-system-info.ps1`

Read-only. Report Windows version, GPU, VRAM, RAM, PowerShell version, git availability, candidate Comfy Desktop locations, and candidate custom-node/model paths. It installs nothing.

### `bootstrap-comfy.ps1`

Install helper. It accepts an explicit Comfy root when auto-detection is ambiguous, verifies git before cloning, installs only packages declared in `node-list.json`, skips matching existing repositories, stops on mismatched repositories rather than force-resetting, and does not automatically download multi-GB model files.

### `validate-comfy-env.ps1`

Read-only validator. It resolves the Comfy root, checks required node directories and model directories, parses workflow JSON, rejects unresolved placeholder node types, reports disk-space information where possible, and emits a compact PASS/WARN/FAIL summary with non-zero exit on required failures.

### `link-workflows.ps1`

Copies workflows into a user-selected Comfy workflow location. Copy is the default, not symlink. It must not silently overwrite changed destination files; conflict behavior must be explicit and documented.

## 9. Codex local operator contract

Codex is expected to perform the Windows-side installation. The runbook must tell Codex to:

1. clone or pull `hermes-comfy-desktop`;
2. read this design plus the current Hermes digital-human skill from `skills-share`;
3. run read-only system-info collection;
4. detect the actual Comfy Desktop root and stop if ambiguous;
5. inspect existing nodes/models before installing anything;
6. install only missing required node packages;
7. report model files that require download and exact destination folders;
8. validate the environment;
9. install/open the single-image workflow first;
10. restart Comfy Desktop if required;
11. run a single-image smoke test with user-supplied references;
12. collect errors and adjust only after evidence;
13. enable the triple workflow only after the single workflow passes.

Codex must not force-reset unrelated repositories, delete arbitrary nodes, overwrite unknown model files, or invent a Comfy path when detection is ambiguous.

## 10. Acceptance milestones

### Milestone A — repository completeness

Pass when all documented config/docs/scripts/workflow/test files exist, JSON/YAML parse, PowerShell scripts parse, the README/runbook provides an unambiguous order, and no Hermes registry change is introduced.

### Milestone B — local single workflow

Pass when Comfy Desktop starts, required nodes load, required model paths resolve, `hermes-dh-v1-single.json` opens without missing-node errors, and one 3:4 candidate can be generated from explicit slots.

### Milestone C — usable identity behavior

Human-gated pass. The candidate must be recognizably the approved identity, not inherit the wardrobe/pose/scene reference person's face, follow the pose well enough to be useful, keep plausible body perspective, and integrate the scene sufficiently for iteration.

### Milestone D — three-shot workflow

Pass when three explicit shot contracts can be queued from the same upstream assets, execute sequentially on the 8 GB GPU, vary pose/prompt/seed independently, and save traceable filenames.

## 11. Testing strategy

Repository-level validation must cover:

- JSON/YAML parseability;
- PowerShell parse/basic correctness;
- explicit failure for unresolved Comfy root;
- required-vs-optional node behavior;
- conflict-safe workflow copying;
- absence of unresolved placeholder node types;
- no committed large model binaries or identity assets.

Local image-quality acceptance remains a runtime/human test on the user's machine and is not inferred from repository validation.

## 12. Error-handling policy

Use "stop rather than guess" for identity-critical or filesystem-destructive ambiguity.

Hard failures include: unresolved/ambiguous Comfy root, malformed required config/workflow, required nodes unavailable after an attempted install, or a workflow referencing unavailable node classes.

Warnings include: optional enhancement nodes absent, recommended-but-not-required model variants absent, or a non-critical diagnostic unavailable.

## 13. Implementation order

1. Repository documentation/config schema and validators.
2. Read-only environment discovery.
3. Safe custom-node bootstrap and workflow-copy tooling.
4. Single-image V1 workflow and workflow notes.
5. Local single-image smoke test through Codex.
6. Triple sequential shot task after single-path acceptance.

This order intentionally prevents spending time on the three-shot production layer before the core local identity-controlled path works on the target machine.
