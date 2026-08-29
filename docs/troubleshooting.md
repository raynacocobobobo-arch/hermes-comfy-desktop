# Troubleshooting

Use evidence before changing models, nodes, or weights. Preserve the Hermes identity contract while diagnosing runtime failures.

## Workflow opens with missing nodes

Check, in order:

1. Comfy Desktop startup log for import/dependency errors.
2. The selected package directory exists under the actual `custom_nodes` path.
3. The directory is the expected git repository and its `origin` matches `config/node-list.json`.
4. The installed package version actually exposes the node class referenced by the exported workflow.
5. Restart Comfy Desktop after installation or dependency changes.

Do not edit workflow JSON to invent a similar-looking node class.

## `validate-comfy-env.ps1` says a required node is unresolved

This is intentional before the local compatibility pass. Verify the package against the real Comfy runtime, then set both `resolved_repository` and `folder_name`. Candidate URLs are hints, not automatic selections.

## Required model is unresolved or missing

Read the verified node package documentation. Resolve the exact filename and folder first. Show the user source, expected size when known, and destination before a multi-GB download. Never commit the model file.

## CUDA out of memory

1. Confirm batch size is 1.
2. Disable the optional face-detail pass.
3. Reduce first-pass dimensions while keeping roughly 3:4.
4. Keep only the mandatory pose ControlNet active.
5. Reduce or stage body/wardrobe/scene reference adapters.
6. Restart Comfy Desktop to clear stale allocations.
7. If still unstable, reconsider the selected adapter/model combination rather than stacking more controls.

Do not solve OOM by enabling three full sampler branches in parallel.

## Face identity drifts

Check:

- the approved `face` image actually reaches the identity-aware node;
- no wardrobe/body/pose/scene image reaches the identity input;
- the identity package/model is compatible with the SDXL path in use;
- non-identity adapter influence is not dominating;
- the target head angle is reasonably supported by the available identity evidence.

If the user says the person is wrong, the candidate fails identity regardless of aesthetic quality. Do not reuse it as a new identity source.

## Wardrobe reference changes the face

Treat this as non-identity conditioning contamination. Lower, stage, or isolate the wardrobe reference path. Do not redefine identity from the wardrobe image.

## Pose is ignored

Inspect the pose-preprocessor output first. If the skeleton/keypoints are wrong, fix the source pose or preprocessor selection. If the preprocessor is correct, verify the ControlNet model is SDXL-compatible and actually connected to the sampling conditioning path.

## Pose is correct but anatomy is bad

Check head/body relationship, hands, joints, and prop geometry. If the failure is broader than facial identity, classify `REGENERATE`, not `FACE_REPAIR`.

## Scene perspective looks wrong

Check:

- camera/framing language in the shot contract;
- subject scale relative to scene geometry;
- pose orientation versus scene camera angle;
- scene reference dominance;
- lighting direction and contact/grounding.

Lower scene-reference dominance or regenerate with corrected camera/pose instructions rather than using a bad scene composite as a new upstream source.

## Base image is good but face alone is wrong

Only consider `FACE_REPAIR` if composition, body, pose, scene, head size/angle, neck connection, and major lighting are already worth preserving. The approved identity master remains authoritative. A repaired result stays downstream content.

## Bootstrap refuses an existing node folder

This is a safety feature.

- Existing non-git folder: inspect manually; do not delete automatically.
- Existing git repo with a different origin: determine which installation is correct; do not force-reset it.
- Matching git origin: bootstrap should skip it without cleaning/resetting.

## Workflow copy refuses overwrite

Default conflict behavior is `Stop`. Compare the local workflow with the repository version. If you intentionally want to preserve the local copy and install the repository version, rerun with:

```powershell
-ConflictAction Backup
```

The script creates a timestamped backup before copying.

## Three-shot mode causes memory pressure

Three-shot semantics are sequential. If the implementation holds three complete sampler branches resident at once, it violates the V1 hardware contract. Replace it with a reusable graph / queue helper / sequential submission mechanism supported by the actual Comfy runtime.
