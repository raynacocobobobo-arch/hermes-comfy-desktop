# Workflow Notes

## Current state

Executable Comfy workflow JSON is intentionally not committed yet. Exact custom-node classes and sockets must be verified in the target Windows Comfy Desktop runtime and exported from that runtime.

The repository-side tooling is allowed to be complete before the actual graph is known; `tests/validate-repo.ps1 -AllowIncompleteWorkflows` is the pre-runtime validation mode.

## Fixed slot contract

```text
FACE      = IDENTITY ONLY | CRITICAL
BODY      = BODY ONLY     | HIGH
WARDROBE  = WARDROBE ONLY | NORMAL
POSE      = POSE ONLY     | NORMAL
SCENE     = SCENE ONLY    | NORMAL
```

`face` is the sole facial identity authority. Generated output is downstream content only.

## Single-shot V1 defaults

Starting policy for RTX 4060 8 GB / 16 GB RAM:

- SDXL baseline;
- approximately 768x1024;
- batch size 1;
- one sampler path;
- one mandatory pose ControlNet;
- face-detail enhancement disabled for the first smoke test;
- body/wardrobe/scene adapter influence may be staged or reduced if VRAM or identity conflict requires it.

Backend numeric weights are implementation details and must be recorded here only after a concrete graph runs successfully. They are not Hermes role weights.

## Three-shot semantics

```text
shared: face + body + wardrobe + scene
SHOT01: pose01 + prompt01 + seed01 + framing01
SHOT02: pose02 + prompt02 + seed02 + framing02
SHOT03: pose03 + prompt03 + seed03 + framing03
execution: sequential
parallel_full_sampler_branches: false
```

The preferred mechanism is a reusable graph with sequential queue/submission behavior. If the installed Comfy runtime requires another documented mechanism, preserve the sequential memory behavior.

## Output policy

Each final output name should include:

- character/project token;
- workflow version;
- shot id;
- seed or execution identifier.

Outputs must not be written into identity/body master asset directories automatically.

## Human gate

Runtime completion does not equal identity success. The user must explicitly approve likeness before a candidate is considered usable under the Hermes Identity Gate.
