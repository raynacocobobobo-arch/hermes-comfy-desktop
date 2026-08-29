# Hermes Comfy Shot Contract

```yaml
character_token: DH001
ratio: 3:4

assets:
  face: <approved identity image path>
  body: <approved body image path>
  wardrobe: <wardrobe reference path>
  pose: <pose reference path>
  scene: <scene reference path>

shot_id: SHOT01
framing: medium-close
camera_angle: front
subject_orientation: facing camera
action: natural standing pose
prompt_suffix: realistic photography, natural skin texture, coherent perspective
seed: 123456789
```

## Slot semantics

- `face` = `IDENTITY ONLY | CRITICAL`
- `body` = `BODY ONLY | HIGH`
- `wardrobe` = `WARDROBE ONLY | NORMAL`
- `pose` = `POSE ONLY | NORMAL`
- `scene` = `SCENE ONLY | NORMAL`

The operator must attach the actual approved images. A filename, alias, or prior generated image is not a substitute for the authoritative identity input.

For three-shot production, duplicate only the shot-specific fields (`shot_id`, `pose`, `framing`, `camera_angle`, `subject_orientation`, `action`, `prompt_suffix`, `seed`). The upstream `face`, `body`, `wardrobe`, and `scene` stay shared and authoritative; outputs do not become inputs for later shots.
