# Implementation notes — 0.8 beta

Godot 4.5.1, Compatibility rendering. 1280×720 design viewport, scalable UI. No third-party runtime libraries or network requests during play.

`scripts/building.gd` constructs four 25×36 metre floors at 4.5 metre intervals. Each has paired corridors, side rooms, return passages and a U stair. Visible treads sit over smooth double-sided ramp collision surfaces. A separate AStarGrid2D on each floor supplies horizontal routing; explicit 3D waypoints connect stair flights and landings. An active stair route is retained until an agent exits the stairwell. Fixtures on distant floors stop contributing light.

`door.gd` uses RigidBody3D leaves constrained by HingeJoint3D to static anchors. A bounded angular motor moves toward the requested angle; collision can resist it. Locks, jams, forcing, contact-closing sounds and enemy forcing are separate states. Interactions select the actual visible door collider. The exit is a hinged door followed by a narrative interaction, not a teleport trigger.

`player.gd` combines acceleration, coyote time, buffered jumping, crouch clearance, stamina, slide momentum and ADS. Recoil is a critically damped pitch spring independent of mouse baseline; the screen reticle and projected shot direction share its displacement. No damage is dealt through world geometry. Fire hazards check height as well as horizontal distance.

The flashlight drains at 0.46 units/second. Cells restore 40 units; generators restore 23/second while E is held. A depleted cell retains a 5 metre reserve beam. Beam inspection, line of sight and distance expose enemy intent. Active light broadens enemy awareness. Apex pulses have a 1.5 second warning, require unobstructed sight, drain 16 charge and cause temporary flicker. They do not directly damage health.

`enemy.gd` separates role/difficulty from remembered intention. Lurkers use ranged fire, rushers close quickly, stalkers stop when observed and approach blind spots, and the apex adds a sight-blockable pulse. Sight checks world occlusion; hearing stores the last heard position. Windups telegraph attacks, early aim tracks and late aim locks. Hits interrupt ordinary windups. Calm frightened soldiers and certain guards can surrender. Milo's refusal rules are in `milo.gd`, never randomized.

`weapon_mesh.gd` creates original service pistol, rifle and shotgun shapes. `main.gd` emits physical casings, impact marks, particles, muzzle smoke and brief tracers. `sound.gd` mixes original synthesized effects, positional shadow cues and licensed music. The scene post-effect adds restrained grain, vignette and nearby-fire heat distortion. It is below the HUD and honors reduced motion.

Memory chapters and physical floors are distinct. Exit progression is independent of body count. The final memory requires three persistent clues. Save settings preserve checkpoint content. Restarting or changing chapters frees the previous world and its physics bodies.

## Editing and checks

Import with `godot --headless --path . --editor --import --quit`.
Run `godot --headless --path . --script res://tests/redesign.gd` for the gameplay suite and `res://tests/navigation.gd` for physical cross-floor enemy traversal. `res://tests/effect_cleanup.gd` checks effect cleanup during a memory transition. The earlier 0.3 integration suite has been superseded because its coordinates refer to the old building. Use an isolated `XDG_DATA_HOME` when running checks so test saves do not overwrite a player's checkpoint.

Export using the Windows Desktop preset after installing official Godot 4.5.1 templates. The delivered Windows executable is the same 4.5.1 runtime as version 0.3, with a newly exported external resource pack. Source contains all assets and no editor caches. The game has no online dependency.

## Character and room pipeline

`tools/build_characters.py` builds four skinned glTF files from the included CC0 MakeHuman base mesh, skeleton, weights and clothing. It uses Python 3 and NumPy, with no Blender dependency. Original garment barycentric mappings transfer weights to a compact 50-bone hierarchy; skin weights are normalized and limited to four per vertex. The source art and license are retained under `licenses/MakeHuman/`.

`human_rig.gd` solves two-bone limbs, finger poses, distance-driven stance/swing gait and ground contact. Facing follows intent and movement, independently of the camera. Dead Shadows retain a collapsed mesh after their collision is disabled. Animation is procedural, not a physics ragdoll. The first-person arms and body are separate cropped meshes sharing the same rest skeleton; this avoids rendering the avatar's head inside the camera.

`room_props.gd` combines imported glTF furniture with rounded meshes and lathed clutter. Large furniture gets simple explicit collision; tiny clutter is visual only. Repeated small details share MultiMesh draw calls, partitioned by floor. Imported textures must exist before reimporting their glTF scenes.

The intro owns the camera while active, suspends enemy decisions, and releases input state on handoff or skip. Pause suspends its clock. `tests/immersion.gd` exercises that handoff, continued control after damage, shoulder clearance, skeletal pose changes and persistent death bodies. The HUD remains outside the post-process pass. Focus blur is a controlled cinematic screen effect, not depth-aware DOF.

## Remaining production work

Hand poses and animation blending can be refined further by a character animator. Recorded dialogue, more bespoke room art, wider hardware/performance testing, native Windows QA and further human playtesting remain. No claim of AAA graphics or physically simulated fire is made. The horror reference directs the composition, layout and material palette; the prototype is not a pixel-identical reconstruction of that artwork.

## 0.6 placement, collision and locomotion changes

RoomProps.imported measures all child meshes in the asset root, corrects the root's floor offset, exposes surface_y, and creates unscaled static collision bodies with matching yaw. Table tops and legs, and chair seats/backs/legs, have separate box proxies. Sofas and authored beds/fireplaces/bags have simpler solid bounds. The footprint registered with routing includes the transformed bounds and 0.43 m clearance. Tiny cosmetic clutter remains static visual geometry; it is not a rigid-body interaction system.

SoldierRig uses the uploaded FBX model's original skeleton. It retains the two prop sockets from the matching animation rig and maps common bone tracks directly, without retargeting onto MakeHuman. Eleven clips are cached in one AnimationLibrary. An AnimationPlayer is advanced manually after CharacterBody3D movement, using measured displacement, local movement direction and model scale. Aim/fire and damage can layer onto the moving lower body. Two supplied death variants finish and hold their last pose; there is no ragdoll. Small analytical leg corrections support ramps. MakeHuman remains in use for first-person hands/body and the elderly Milo scene.

Enemy route smoothing tests the full body before taking a shortcut and keeps the explicit stair route. Separation is length-limited; destination braking avoids perpetual repathing at the final point. Unreachable motion triggers replanning. Enemy collision uses world, Shadows and player layers; the player now also collides with Shadows. Dead bodies stop blocking traversal.

Additional verification: tests/props_and_motion.gd covers furniture grounding, imported collision, rotated tabletop height, open space underneath, physical player traversal against furniture, supplied locomotion clips, in-place animation, aim/fire, hit and death. tests/immersion.gd now checks the supplied enemy rig instead of assuming the old MakeHuman bone layout.

## 0.7 control recovery, room plan and firearm combat

main.gd centralizes control recovery, restores the current gameplay camera and clears stale locks only outside cinematics/transitions/death. Input uses unscaled screen_relative motion with a relative fallback. A lost-capture click is consumed, F11 recaptures after the window change, and application focus loss pauses. Exit to Desktop uses the same idempotent shutdown path as the window close action.

room_props.gd places bedroom headboards 0.10 m from the rear wall and uses perimeter wardrobe/desk/dresser storage, two bedside tables and a central approach. The final medical bed is created through this layout, avoiding duplicate furniture in the room. Its wristband interaction is on the bedside table. The circuit panel's back face is at x=5.88, coincident with the east corridor wall; the interaction target is on its visible front side.

enemy.gd equips every hostile role independently of silhouette/archetype. The combat states add burst and reload; bursts use 2-3 rounds with 0.16-0.25 s spacing, followed by recovery. An early windup tracks the player's standing/crouching torso, then holds its aim point. A world/actor ray starts at the animated muzzle, excludes the shooter, and checks obstruction between torso and muzzle. Friendly actors block rounds without crediting the player with their deaths. Empty magazines play the supplied rifle reload clip. Existing stalker observation and apex pulse behavior remain.

soldier_rig.gd solves the upper-body barrel alignment iteratively because shoulder rotation also moves the muzzle. A damped recoil spring and partial compensation create a returning kick. The muzzle flash/light, positional report, smoke, casings and impacts are tied to actual rounds. Deaths retain the rifle for hostile characters; noncombatants and surrendered people show empty hands.

Additional checks: tests/controls_and_combat.gd runs in a rendered window for real mouse-capture behavior, and verifies mount contact, panel reach, bedroom placement, firearm assignment, four-role ranged damage, barrel alignment, cover, burst cadence, crouching targets and reload. tests/quit.gd exercises the clean exit action. The Windows updater uses hash comparison and backups before replacing known build/source files; native Windows execution remains a separate QA requirement.


## 0.8 camera, stability and rendering

The Camera3D is top-level. sync_camera composes unsmoothed input yaw/pitch with render-rate visual offsets, and interpolates only previous/current CharacterBody positions. It resets on external repositioning; cinematics supply their authored head height/tilt and explicitly sync. The camera-mounted flashlight, arms and weapon follow the rendered view. Collision, stamina and fire cadence remain in physics. Recoil integration uses small substeps; visual blends remain bounded through slow frames. Near-wall probes run at 20 Hz. Camera depth range is 0.05–70 m.

SoldierRig caches upper-body track mappings. Rest translations/scales are restored before each animation advance; procedural rotations use orthonormalized bases. The rifle is top-level under the rig, with the socket position/orientation solved directly and uniform character scale applied explicitly. Rendering and ballistics use the same weapon_transform. The original rifle is at 88% of its former scale and uses gunmetal. The role's nonuniform body proportions do not distort the rifle.

Static direct opaque meshes are merged by material and 8 m spatial cell. Their collider children are reparented with global transforms preserved; the interactable panel remains addressable. Dynamic doors, characters and transparent surfaces are excluded. Furniture MultiMeshes are also grouped by spatial cell. Merged chunks have a 42 m visibility distance. Lighting chooses at most 12 nearby fixtures within 15 m and 5 m vertical distance, refreshed at ~8 Hz with selection hysteresis. Only the flashlight casts real-time local shadows. Fire/light modulation is low amplitude; muzzle lights are short and restrained. Hidden ambient particles no longer draw; physics collision stays active across all floors.

Effects have separate caps: 12 tracers, 16 casings, 8 muzzle-smoke emitters, 12 impact emitters and 40 impact marks; far-away casing/smoke effects are skipped. Casings freeze after one second and expire after 2.5 seconds. Audio caps transient voices at 24. In normal gameplay the postprocess takes one screen sample; focus blur uses its additional samples only when active.

Reproduce with tests/performance_probe.gd (rendered), tests/camera_quality.gd (rendered with 3D disabled to isolate view timing), and tests/stability_probe.gd (headless). The stability probe tests 36,000 manual pose updates, not ten minutes of real-time GPU play. Shader grain and silhouette detail frequencies are reduced to avoid high-frequency shimmer. Small props remain simple physical proxies.
