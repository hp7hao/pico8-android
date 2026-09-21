# pico8-android Spec

**Version**: 0.1.0
**Status**: Active
**Level**: product
**Owner**: pico8-android
**Parent**: docs/specs/GLOBAL_SPEC.md
**Last Reviewed**: 2026-09-21

## Purpose

Define pico8-android as the Titan 2 appliance that wraps a user-provided
Raspberry Pi PICO-8 binary so the official Lexaloffle editor and player run on
that handheld.

## Scope

In scope:

- the GoIndie2 product job: boot, keep alive, and operate official PICO-8 on
  Titan 2;
- the Android wrapper boundary around the user-owned binary, including storage
  mapping under `/Documents/pico8/data`, editor shortcuts, My Projects browser,
  controller/keyboard input, and Splore versus command-prompt relaunch.

Out of scope:

- PICO-8 itself; the app never ships the commercial binary;
- catalog browse, `.p8mod` kernel or export, or agent Create;
- XiaoweiOS HOME-lane or shipped-surface identity;
- Godot/shim implementation walkthroughs. User-facing wrapper mechanics that
  are not this job identity remain in `projects/pico8-android/README.md` as
  non-canonical documentation.

## Authority And Ownership

pico8-android owns this Titan 2 official-binary job. Job assignment across
PICO-8 products is owned by `docs/specs/pico8_product_landscape_spec.md`.

The parent repository owns the submodule path, branch hint, and pin through
`.gitmodules` and `docs/specs/submodule_workflow_spec.md`. Upstream wrapper
documentation may describe frontend behavior; it must not become a second
GoIndie2 product-job owner.

## Product Contract

- The product exists so a legally purchased Raspberry Pi PICO-8 build can run
  on Titan 2, including the native code, sprite, map, SFX, and music editors.
- Users supply the executable. First launch fails closed until that binary is
  present.
- Cartridge and config layout mirrors a normal PICO-8 `data/` tree under
  `/Documents/pico8/data` so carts can be copied or synced from PC.
- Wrapper chrome may expose editor-tab shortcuts, a read-only My Projects tree
  for `.p8` sources, virtual keyboard, and controller mapping. It must not grow
  a catalog gallery, `.p8mod` authoring kernel, or agent conversation.
- Audio and exec compatibility quirks that keep official PICO-8 alive on Titan
  2 stay inside this wrapper. They are not reasons to reimplement PICO-8 in
  Electron, WASM, or fake08.

## Failure And External Contracts

- Missing storage permission, missing binary, or child-process failure is
  visible in the wrapper; the app must not pretend PICO-8 is running.
- Targeting an older Android SDK to exec the user binary is an accepted
  wrapper constraint, not a XiaoweiOS platform policy.

## Validation Contract

- Required evidence: the isolated Android debug-build path in
  `projects/pico8-android/README.md` for wrapper changes; Titan 2 runtime
  evidence for input, editor, or audio claims; canonical spec validators for
  this product root.
- Validation commands: `projects/pico8-android/scripts/build-android-debug.sh`
  for APK changes, plus `node scripts/specs/validate-specs.mjs` after spec
  edits.

## Agent Contract

| Field | Contract |
|---|---|
| Governed files | `projects/pico8-android/**` except recovered bootstrap blobs and ignored build outputs |
| Invariants | Remain a Titan 2 official-PICO-8 wrapper; never ship PICO-8; do not add FCDB, `.p8mod` kernel, agent Create, or a second creator/player product |
| Validation | Run the project Android debug build for wrapper changes and canonical spec validators for authority changes |
| Parent specs | `docs/specs/GLOBAL_SPEC.md`, `docs/specs/pico8_product_landscape_spec.md` |
