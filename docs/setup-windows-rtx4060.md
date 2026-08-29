# Windows / RTX 4060 8 GB Setup Guidance

## Hardware profile

Target: RTX 4060 8 GB VRAM, 16 GB system RAM.

V1 is intentionally conservative. The first acceptance run should use one SDXL sampler path, batch size 1, approximately 768x1024 output, one mandatory pose ControlNet, and optional face-detail processing disabled until the base path is stable.

## Memory policy

- Start with one candidate at a time.
- Keep the three-shot mode sequential.
- Do not build three simultaneous full sampler branches.
- Do not enable multiple heavy ControlNets by default.
- Stage or weaken non-identity reference adapters if the combined stack causes OOM or conditioning conflict.
- Do not raise the first-pass target to 1024x1536 merely for quality; prove the lower-cost path first.
- Restart Comfy Desktop after installing or changing custom nodes before judging missing-node failures.

## First local sequence

1. Run `scripts/collect-system-info.ps1` with an explicit Comfy root if known.
2. Inspect the actual `custom_nodes` and `models` locations.
3. Verify current compatible identity, reference-adapter, and pose-preprocessor packages.
4. Resolve `config/node-list.json` and `config/model-recommendations.yaml` with concrete package URLs/folder names/model filenames.
5. Obtain user approval before large model downloads.
6. Run `scripts/bootstrap-comfy.ps1`.
7. Restart Comfy Desktop and inspect startup logs.
8. Run `scripts/validate-comfy-env.ps1`.
9. Build/export the single-shot workflow in the actual Comfy runtime.
10. Generate exactly one test image using the five explicit asset slots.

## Success is not just runtime success

A generated image can complete technically and still fail Hermes identity requirements. Human review must check likeness first. If the face is wrong, mark the candidate failed for identity/reference reuse even if pose, clothing, or scene quality is strong.

## Escalation order for CUDA OOM

1. Ensure batch size is 1.
2. Disable optional face-detail processing.
3. Reduce output dimensions while keeping approximately 3:4.
4. Reduce simultaneous non-identity adapter paths or stage them.
5. Verify only the required pose ControlNet is active.
6. Restart Comfy Desktop to clear stale allocations.
7. Only then consider alternative model/node strategies.
