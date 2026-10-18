# Credits and asset provenance

## Concept

AFTERIMAGE premise, themes, characters, and creative direction: the user's supplied concept and original Godot project. Original project files were provided as `afterimage-game(2).rar`.

This build adds original GDScript systems, environment composition, vector shadow silhouettes, interface artwork, shaders, synthesized sound effects, and implementation of the supplied narrative. No art, dialogue, UI layouts, or music was extracted from Persona or a commercial horror game. The interface draws on broad cut-paper, poster, and horror design techniques.

## Music — copyrighted and used under license

**“Unseen Horrors” — Kevin MacLeod (incompetech.com)**

Licensed under Creative Commons Attribution 4.0 International:
https://creativecommons.org/licenses/by/4.0/

Official track and attribution:
https://incompetech.com/music/royalty-free/index.html?Search=Search&isrc=USUAN1400043

Source audio:
https://incompetech.com/music/royalty-free/mp3-royaltyfree/Unseen%20Horrors.mp3

Changes: reencoded to Ogg Vorbis, looped by the game, and mixed with changing volume during encounters. The underlying composition and recording remain copyrighted by the rights holder. Keep this attribution when redistributing a build containing the track.

## Models and particle textures

**Kenney — Blaster Kit 2.1**
https://kenney.nl/assets/blaster-kit
License: Creative Commons CC0 1.0 Universal.
https://creativecommons.org/publicdomain/zero/1.0/

Included models: `blaster-a.glb`, `blaster-c.glb`, `blaster-g.glb`, and their palette texture. Changes: material/shader replacement, orientation, first-person positioning, procedural hands, recoil, and muzzle effects. The stylized models represent fictional weapon archetypes in this game.

**Kenney — Particle Pack**
https://kenney.nl/assets/particle-pack
License: Creative Commons CC0 1.0 Universal.
Included textures: flame_01, smoke_01, smoke_04, muzzle_01, spark_01. Used with original particle settings and colors.

Original license texts are included in `licenses/Kenney-blasters.txt` and `licenses/Kenney-particles.txt`.

## Fonts

**Bebas Neue** — Ryoichi Tsunekawa / Dharma Type, SIL Open Font License 1.1.
https://fonts.google.com/specimen/Bebas+Neue
https://github.com/google/fonts/tree/main/ofl/bebasneue

**Barlow Semi Condensed** — Jeremy Tribby, SIL Open Font License 1.1.
https://fonts.google.com/specimen/Barlow+Semi+Condensed
https://github.com/google/fonts/tree/main/ofl/barlowsemicondensed

Unmodified font files; OFL texts included in `licenses/`.

## Engine

Godot Engine 4.5.1 — Juan Linietsky, Ariel Manzur, and Godot Engine contributors. MIT license.
https://godotengine.org/license/
https://github.com/godotengine/godot/blob/4.5.1-stable/LICENSE.txt

Godot's third-party dependency notices are included in `licenses/Godot-COPYRIGHT.txt`.

## Original assets

`assets/shadows/*.svg`: original editable vector drawings, deliberately made from a single silhouette path, small facial marks, and a few internal strokes. Change the path points to create new enemies without a modeling pipeline.

`assets/audio/*.wav`: original synthesized weapon, movement, impact, UI, ambience, and transition effects. The licensed music is the separate `.ogg` file.

## Version 0.4 additions

Poly Haven PBR materials, CC0:
- Painted Plaster Wall, Amal Kumar: https://polyhaven.com/a/painted_plaster_wall
- Worn Planks: https://polyhaven.com/a/worn_planks
- Concrete Floor 02: https://polyhaven.com/a/concrete_floor_02
- License: https://polyhaven.com/license

The 1K diffuse, OpenGL normal and roughness maps are included in `assets/materials/`, with in-engine tint and world-space tiling. Poly Haven does not endorse this project.

The title-screen artwork in `assets/shadows-v2/forgotten-soldier.png` was generated for this project using image generation, transparent-background mode. Prompt direction: a full-body forgotten soldier, gaunt silhouette, scorched unmarked greatcoat, torn cloth, hollow face, tiny pale eyes, realistic soot and cloth, cold rim light; no logos, text, gore, horns, skull mask or cartoon outline. The original three editable SVG shadow drawings remain in source as alternatives.

The active weapons in `scripts/weapon_mesh.gd` are original procedural geometry. The previously included Kenney weapon models remain as optional source assets and retain their CC0 attribution above.

Door, flashlight, casing, collapse and four enemy cues are original synthesized sounds. Existing licensed music is retained; no unlicensed commercial game soundtrack is embedded.

The supplied AFTERIMAGE architectural reference informed the four-floor layout, paired corridors, staircase, warm-fire/cold-shadow contrast and material palette. The reference image and redesign brief are not redistributed in this package. No Blender file was available to import.


## Version 0.5 character and furniture assets

**MakeHuman Community core graphical assets — CC0 1.0 Universal.**
Base human mesh, default rig and weights, male_casualsuit01 garments, shoes04, and old_lightskinned_male_diffuse skin. Asset copyright notices identify Data Collection AB, Joel Palmius and Jonas Hauquier; source notices are preserved.

- https://github.com/makehumancommunity/makehuman
- https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.md
- https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html
- https://creativecommons.org/publicdomain/zero/1.0/

Changes: conversion to metres and glTF, reduced bone hierarchy, normalized four-weight skinning, garment weight transfer, first-person mesh crops, in-engine tint, Shadow material, additional helmet/eyes, and original procedural animation/IK. The CC0 graphical data is included; MakeHuman application code is not included. See `licenses/MakeHuman/LICENSE.ASSETS.md`.

**Poly Haven furniture — CC0.**
- Painted Wooden Chair 02 — Kirill Sannikov: https://polyhaven.com/a/painted_wooden_chair_02
- Wooden Table 01 — Ethan Place: https://polyhaven.com/a/WoodenTable_01
- Sofa 03 — Fran Calvente: https://polyhaven.com/a/sofa_03

Original glTF geometry and 1K texture maps are retained in `assets/models/`. Changes: scene instancing, placement, scaling and simplified collision. License: https://polyhaven.com/license

Other new props, beveled weapon geometry, cinematic camera paths, interface changes and animation code were authored for this build. The existing licensed Kevin MacLeod score is retained.

## Version 0.6 supplied soldier model and animations

**Human Soldier Animations 2.0 FREE — Kevin Iglesias**
https://www.keviniglesias.com/

Supplied by the user as Human Soldier Animations FREE.zip. Selected male idle, forward/backward/side walk, run, rifle aim/fire, damage and death clips are integrated with the matching male dummy model, helmet and rifle. Changes: Godot FBX import, bone-track/socket mapping, layered upper-body poses, charcoal materials, eye cues, role proportions, playback speed matching, transitions and terrain corrections.

The supplied documentation states Standard Asset Store EULA, royalty-free commercial use, no resale and no required attribution. These assets are not CC0. Their original terms continue to apply; the supplied documentation is retained in licenses/HumanSoldier/Human_Soldier_Animations_FREE.pdf. This project returns the user's supplied assets as part of their game project, rather than offering a standalone animation pack.

## Version 0.7 additions

The supplied Kevin Iglesias rifle reload animation is now integrated alongside the existing soldier clips. The user's uploaded room-plan diagram informed bedroom furniture placement; the reference image itself is not redistributed. Weapon effects, burst scheduling, aim/recoil integration, control recovery, wall mounting and layout code are original project changes.


## Version 0.8 recorded sound additions

**The Free Firearm Sound Library — Ben Jaszczak, Brian Nelson, Kevin Heras and Matthew Nanney, CC0.** Uploaded by bart:
https://opengameart.org/content/the-free-firearm-sound-library
Original files: 1911/A_34P.wav, AR-15/D_24P.wav, Mossberg/N_26P.wav.
Edits: first-shot excerpts, mono conversion, 44.1 kHz/16-bit, -3 dBFS peak normalization and tail fades. These replace the synthesized pistol/rifle/shotgun reports.

**Impact Sounds — Kenney, CC0.**
https://kenney.nl/assets/impact-sounds
Selected concrete and wood footstep variations and impactMetal_light_000 casing bounce. Footsteps vary without immediate repeats; stairs use wood. Metal impact converted to mono 22.05 kHz WAV. Original license retained in licenses/KenneyImpact/.
https://creativecommons.org/publicdomain/zero/1.0/

The existing licensed Kevin MacLeod music is retained. No new commercial soundtrack is included.


## Version 0.9 original score and animation polish

**What Remains** — original instrumental cue synthesized for AFTERIMAGE (96 seconds, stereo Ogg Vorbis). Created from additive oscillators, original note sequences, envelopes and delay processing. No third-party samples, lyrics, melodies or commercial soundtrack recordings are used. The reproducible composition source is `tools/compose_score.py` (Python, NumPy/SciPy, FFmpeg). The generated cue and composition source may be used and modified with this project.

The existing Kevin MacLeod recording retains its attribution and CC BY 4.0 license above. Both cues are mixed dynamically and attenuated during subtitles.

NieR:Automata music is not redistributed. The optional external `Music/reflection.ogg` slot loads a user-supplied recording; any recording distributed with a modified game must have the appropriate permission. Square Enix's public NieR usage guidelines are for the specified uses and prohibit combining their materials with content outside the series:
https://www.square-enix-games.com/en_US/documents/nier-automata-and-nier-replicant-ver-1-22474487139-guidelines-for-livestreaming-and-posting-video-images-of-nier-series-titles

Palm-aligned grip targets, first-person sleeve anchoring, finger poses, subtitle scheduling, recent dialogue UI, and adaptive music mixing were authored for this update. Existing asset licenses remain in effect.
