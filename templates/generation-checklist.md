# Hermes Digital-Human Generation Checklist

Evaluate in this order. Identity has priority over aesthetic quality.

## 1. Identity gate

- Face is recognizably the approved person.
- Age impression is consistent.
- Eye shape/spacing, brows, nose, mouth, jaw/chin, and visible hairline remain plausible for the approved identity.
- The face has not drifted toward the wardrobe, pose, body, or scene reference person.

If identity fails, do not promote the candidate into any upstream reference pool.

## 2. Body / perspective

- Body proportions are plausible for the approved body reference.
- Head/body scale is coherent.
- Subject scale matches scene perspective.
- Feet/contact/grounding are plausible when visible.

## 3. Pose / prop geometry

- Pose follows the intended reference strongly enough to be useful.
- Hands, joints, camera/tool/prop geometry are acceptable.
- Head angle and neck connection are compatible with the intended identity.

## 4. Wardrobe contamination

- Clothing structure and styling follow the wardrobe reference.
- Wardrobe reference identity has not leaked into the face.
- Clothing does not create implausible anatomy or perspective.

## 5. Scene integration

- Camera geometry is coherent.
- Lighting direction/intensity is reasonably integrated.
- Subject placement and scale fit the scene.
- Scene reference does not redefine the person's identity.

## Final triage

Choose exactly one:

- `APPROVED` — identity and relevant shot layers pass.
- `FACE_REPAIR` — composition/body/pose/scene/head geometry are worth preserving and only localized facial identity/age impression needs correction.
- `REGENERATE` — failure is broader than face-only repair, including wrong head angle, body, pose, prop, scene geometry, or severe conditioning contamination.

A repaired/generated output remains downstream content and is not automatically an Identity Master.
