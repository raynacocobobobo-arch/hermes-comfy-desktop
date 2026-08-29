# Hermes Comfy Desktop

Standalone local execution layer for Hermes digital-human production on Comfy Desktop.

This repository is **not a Hermes skill**. It does not modify `skill-registry.json` and it does not replace the digital-human policy in `skills-share`. The policy source remains:

`raynacocobobobo-arch/skills-share/plugins/hermes-skills/skills/hermes-creative-digital-human`

This repository owns only local configuration, Windows helper scripts, Comfy workflow exports, validation, and the Codex runbook.

## Target machine

V1 is designed around:

- Windows desktop
- NVIDIA RTX 4060, 8 GB VRAM
- 16 GB system RAM
- Comfy Desktop
- SDXL baseline
- approximately 768x1024 first-pass 3:4 output
- batch size 1 / one candidate at a time

The three-shot mode is sequential. It is not three full sampler branches resident at once.

## Reference contract

Every input image has one explicit role:

| Slot | Hermes role | Purpose |
|---|---|---|
| `face` | `IDENTITY ONLY` | sole facial identity authority |
| `body` | `BODY ONLY` | body proportion / silhouette support |
| `wardrobe` | `WARDROBE ONLY` | clothing and appearance support |
| `pose` | `POSE ONLY` | pose extraction and pose ControlNet |
| `scene` | `SCENE ONLY` | environment / composition support |

Non-identity inputs must never redefine the face. Generated candidates remain downstream content and must not become the identity source for later candidates.

## Installation order

Do not skip ahead. The intended order is:

1. **Discover** the actual Comfy Desktop installation and hardware using `scripts/collect-system-info.ps1`.
2. **Resolve** current compatible custom-node repositories, exact node classes, model files, and destination folders on the target machine. Unresolved required packages intentionally block installation.
3. **Validate** the environment using `scripts/validate-comfy-env.ps1`.
4. **Install the single workflow** only after current package/model compatibility is known.
5. **Run one five-slot smoke test** and have the user judge identity likeness.
6. **Enable three-shot production** only after the single-image path is runtime-stable and identity-usable.

The repository intentionally does not guess current Comfy custom-node class names before Codex checks the real runtime.

## Codex entry point

Use `docs/codex-local-runbook.md` on the Windows machine. Codex must read the design and implementation plan first, then perform read-only discovery before installing anything.

Key rules for Codex:

- do not edit the Hermes skill registry;
- do not force-reset or clean unrelated custom-node repositories;
- do not overwrite unknown model files;
- do not auto-download multi-GB model weights without explicit user approval;
- stop when the Comfy root is ambiguous;
- inspect startup logs after node installation;
- do not claim identity PASS unless the user approves likeness.

## Repository validation

After cloning on Windows with PowerShell 7+:

```powershell
pwsh -NoProfile -File tests/validate-config.ps1
pwsh -NoProfile -File tests/validate-repo.ps1 -AllowIncompleteWorkflows
```

`-AllowIncompleteWorkflows` is only for the pre-runtime stage before exact Comfy node compatibility is resolved and the exported workflows are finalized.

## Production modes

### Single-shot validation mode

One candidate from explicit upstream assets. This is the mandatory first milestone.

### Three-shot production mode

One task package with three explicit shot contracts. Shared identity/body/wardrobe/scene assets are re-used as upstream references, while each shot can vary pose, prompt suffix, framing, and seed. Execution remains sequential on the 8 GB target.

### FACE_REPAIR

FACE_REPAIR is a later, narrow recovery path. It is not the default generation route and does not promote repaired content into a new identity master.

## Status

Repository tooling can be prepared remotely. The actual Comfy workflow JSON must be exported only after Codex verifies the installed Comfy Desktop version, custom nodes, model files, and exact node class/socket compatibility on the Windows target.
