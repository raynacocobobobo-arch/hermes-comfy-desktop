# Hermes Comfy Workflow Design

Status: `PRE-RUNTIME CONTRACT`

This file defines the graph boundaries that are already fixed by the Hermes digital-human contract. It intentionally does **not** invent exact Comfy custom-node class names or socket signatures before the target Windows Comfy Desktop runtime is inspected.

## Fixed semantic graph

```text
SDXL CHECKPOINT
    +
TEXT CONDITIONING / SHOT CONTRACT
    +
FACE — IDENTITY ONLY | CRITICAL
    +
BODY — BODY ONLY | HIGH
    +
WARDROBE — WARDROBE ONLY | NORMAL
    +
POSE — POSE ONLY | NORMAL
    +
SCENE — SCENE ONLY | NORMAL
    ↓
SAMPLING
    ↓
VAE DECODE
    ↓
OUTPUT
    ↓
optional localized face-detail pass
```

## Conditioning boundaries

### Face

The `face` slot is the only facial identity authority. It must enter an identity-aware SDXL-compatible conditioning path verified on the target machine. No body, wardrobe, pose, or scene image may be routed into the identity input.

### Body

The `body` slot supplies body/silhouette support only. Its conditioning strength must remain subordinate to the face identity path when there is conflict.

### Wardrobe

The `wardrobe` slot supplies clothing/appearance information only. If the clothing reference begins to transfer the reference person's facial features, reduce or stage the non-identity adapter path rather than weakening the identity contract.

### Pose

The `pose` slot must be converted to pose geometry through a verified DWPose/OpenPose-class preprocessor and applied through an SDXL-compatible pose ControlNet. The original pose-reference person's identity is not an intended carrier.

### Scene

The `scene` slot supplies environment/composition information only. It may influence placement, framing, perspective, and lighting but must not become an identity source.

## RTX 4060 8 GB starting policy

- approximately 768x1024 for the first 3:4 validation;
- batch size 1;
- one sampler path;
- pose is the only mandatory ControlNet in V1;
- optional face-detail pass disabled for the first base-generation test;
- body / wardrobe / scene reference adapters may be staged or weakened if simultaneous conditioning exceeds VRAM or causes identity contamination;
- do not implement three simultaneous full sampler branches.

## Runtime-resolution gate

Before `workflows/hermes-dh-v1-single.json` may be finalized, Codex must fill the following evidence from the real machine in its working notes and then update this document with concrete values:

| Capability | Required evidence |
|---|---|
| SDXL checkpoint loader | exact built-in/custom node class used and verified checkpoint filename |
| face identity conditioning | exact repository, folder name, node class names, required model files |
| non-identity reference conditioning | exact repository, folder name, node class names, CLIP Vision/adapter files |
| pose preprocessor | exact repository, folder name, preprocessor node class |
| pose ControlNet | exact ControlNet loader/application node and model filename |
| sampler/decode/save | exact classes present in installed Comfy runtime |
| optional face detail | exact package/classes only if enabled |

A concrete workflow must be exported from the actual Comfy Desktop UI/runtime. Hand-invented undocumented node IDs or socket connections are not accepted.

## Single-shot target

The first executable workflow must expose the five explicit input slots plus a shot description and produce exactly one downstream candidate. Runtime success is followed by a human identity gate.

## Three-shot target

Three-shot production is a task-level sequence, not `batch=3` random variation:

```text
shared: face + body + wardrobe + scene
SHOT01: pose01 + prompt01 + seed01 + framing01
SHOT02: pose02 + prompt02 + seed02 + framing02
SHOT03: pose03 + prompt03 + seed03 + framing03
execution: sequential
```

The implementation should use the least-resident documented queue/submission mechanism supported by the verified Comfy runtime.
