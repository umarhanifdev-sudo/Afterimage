# AFTERIMAGE — The Last Room

Version 0.9.1-beta · Windows x64 playable prototype · Godot 4.5.1 source included

The building is burning. Milo is carrying you. You give the orders.

## Play

Extract the entire ZIP. Run **AFTERIMAGE.exe**, keeping **AFTERIMAGE.pck** beside it. No Godot installation is required for the Windows build. Start with **Enter the Building**. The title screen offers Continue after a checkpoint exists.

WASD / arrows move. Mouse looks. Left click gives a fire order. Right click aims. R reloads. Shift sprints. Space jumps. Ctrl or C crouches; press while sprinting to slide. Q lowers or raises the weapon. F toggles the flashlight. E interacts; hold E at a generator or jammed door. Tab opens the memory journal. Escape pauses. F11 toggles fullscreen.

The camera follows the pair as Milo carries the injured soldier. The weapon represents Milo's hands; the player gives fire orders. There is no separate follower character to escort. This is an explicit first-person interpretation of the premise.

## Find your way

There are four physical floors, two corridors on each floor, and a central U-shaped staircase. The current floor appears in the upper-left HUD. Floor numbers are separate from memory chapters. To climb, take the flight that rises ahead, cross its landing, turn back and climb the other flight; repeat for each floor.

The exit circuit is on **Floor 02**, east corridor just north of the stairs. The fire exit is at the north end of the east corridor on **Floor 04**. Restore the circuit, open the hinged fire door, then interact beyond it. The exit never requires killing everyone.

Battery cells are in west-side rooms; hand generators sit beside each floor's south stair entrance. A depleted battery leaves a short reserve beam. Hold E to recharge, but the sound can attract nearby Shadows. Doors can block sight and gunfire; Shadows can force unlocked doors after a delay.

Hold the flashlight on a silhouette to reveal its intent. Lowering the weapon is an invitation, not a guarantee. Keep distance, stop firing, and give a willing soldier time. Shapes and difficulty variants do not determine innocence. Milo's refusals follow what he has recognized and remembered.

## Four shadow behaviors

- **Lurker:** slow armed pressure; sustained light interrupts its approach. Watch its attack tell.
- **Rusher:** fast direct pursuit and close strikes; bright light makes it more aggressive.
- **Stalker:** freezes when watched at a distance, then closes from outside your view.
- **Apex:** larger and more durable. Its delayed pulse disrupts the flashlight; break line of sight before it completes.

## Polish update — 0.9

The firing hand now follows a calibrated palm contact on each weapon, including its rotation. The support hand grips the fore-end or flashlight, releases for reloading, and returns to its grip. First-person sleeves continue below the camera instead of showing detached shoulder edges. The pistol, rifle and shotgun retain their existing recoil and ballistics.

Dialogue receives word- and punctuation-based reading time, short gaps between sentences, and panels that grow to fit wrapped text. Pause and black-screen fades preserve reading time. Old contextual comments expire, repeated lines are suppressed, and chapter transitions wait for the final sentence before fading. Enemies hold during that transition. Settings offer **Long subtitle duration** and **Large subtitles**. **Tab → Recent Dialogue** shows the three most recent spoken lines from this session; dialogue remains text-only.

**What Remains** is a new original 96-second instrumental cue, with soft piano-like tones and sustained harmonies. It plays during quiet exploration and remembrance, crossfades into the existing licensed tension score during danger, and ducks beneath dialogue. The ending fades out the burning-building ambience. The original composition generator is included in `tools/compose_score.py`.

The NieR:Automata soundtrack is not bundled. To use your own licensed Ogg Vorbis recording, place it at **Music/reflection.ogg** beside the Windows executable and restart the game. It replaces the reflective score; the built-in cue remains the fallback. See Music/README.txt.

## Door hotfix — 0.8.1

Controlled, collision-checked hinges replace motor-driven rigid doors. Doors stop against actors and walls, resume once clear, and have floor/header clearance. Forced opening swings away from the actor. Locks and jam timing are preserved. See LAST_LOOP.txt for the final memory route.

## What changed in 0.8 beta

The camera now responds to mouse movement immediately on render frames, with interpolated body translation between collision ticks. Head bob, roll, impact flinch and recoil shake are calmer. The recoil spring stays stable through slow frames; pause, menus, teleports and intro handoff retain control recovery. Camera depth range is tightened to reduce surface shimmer, and low-battery light modulation is smoother.

Enemy rifles use a rigid, uniformly scaled attachment, independently of animated bone shear. Their muzzle rays match their rendered barrel after aim, recoil and reload. Gunmetal surfaces make the supplied rifle easier to read. Hostiles remain armed; frightened and peaceful people keep empty hands.

Static architecture is baked into material/spatial groups; furniture details use smaller spatial batches. A local 12-light budget replaces lighting three full floors at once. Fixture shadows are removed while the player's flashlight retains shadows. Distant ambient particles are culled, normal gameplay skips unused blur samples, grain/heat distortion are quieter, and default MSAA is 2x. Casings, smoke, decals, tracers and audio voices have explicit limits. Casings settle and expire sooner.

Recorded pistol, rifle and shotgun reports replace the synthesized shots. Varied concrete/wood footsteps and metallic casing bounce use CC0 recordings; sources and processing are documented in CREDITS.md. The existing licensed score is retained.

This is a beta. See VALIDATION.txt for measured software-renderer results and Windows testing limits. The benchmark is not a prediction of FPS on your laptop.

## What changed in 0.7 beta

Bedrooms follow the supplied room plan: the headboard meets the rear wall, two bedside tables flank the bed, storage sits along the perimeter, and the doorway opens onto clear floor space. The medical memory uses the same arrangement, with the wristband on its bedside table. The exit circuit is mounted flush to the east corridor wall, and its interaction point remains in front of the panel.

All hostile archetypes carry rifles. Frightened, fleeing and surrendered people remain unarmed. Hostiles brace for short bursts, fire from their animated muzzle, show flash and recoil, eject casings, leave impacts, recover, and use the supplied rifle reload clip when empty. Walls block muzzle fire. Aim accounts for a crouching player; the late part of the windup locks the target point so movement and cover can avoid fire.

Camera control recovers after menus and fullscreen changes, clears stale gameplay locks, and uses screen-relative mouse movement. If mouse capture is lost during play, click once to recapture without firing. Losing application focus pauses the game. The main menu now includes Exit to Desktop.

## Update your existing Windows folder

Close the game. Extract this ZIP into a separate folder, then run **Update-v4.cmd** from the extracted AFTERIMAGE folder. It targets **C:\Games\AFTERIMAGE-Windows-and-Source\v4**, also recognizes an AFTERIMAGE subfolder there, and backs up overwritten files under Backups before copying the update. It updates the game and source; existing user-data saves are retained. The script must run on your PC to change that folder.

For another location, run Update-Local-Game.ps1 with its TargetDirectory parameter. You can also run the newly extracted AFTERIMAGE.exe directly without updating the older folder.

## What changed in 0.6 beta

Furniture is grounded from its measured mesh bounds. Chairs, tables, sofas, beds, shelves, bags and fireplaces now block movement; tabletop and chair collision use separate parts instead of filling all empty space. Cups, papers and lamps sit on measured surfaces. Unsupported pickups have stands or crates, wall frames meet the walls, and stacked beams meet the floor and each other.

Shadows now use the supplied Kevin Iglesias soldier model and authored idle, directional walk, run, rifle aim/fire, hit and death clips. Their charcoal material, pale eyes and distorted archetype proportions preserve their identity. Animation follows actual collision movement, with speed matching, blended transitions and small foot corrections on stair ramps. Corpses remain after the death animation.

Enemy steering now limits crowd-avoidance speed, follows safe shortcuts between grid waypoints, brakes near its destination and replans when stuck. Player/enemy bodies collide. The existing four archetypes, intent reveals, Milo refusals and memory progression remain.

## What changed in 0.5

Shadows are now complete skinned 3D people with 50 deform bones, textured garment geometry, boots, distorted proportions, hollow luminous eyes and rounded helmets. Distance-driven walk/run cycles use leg IK and ground probes; idle breathing, turning, attack preparation, hit reactions, surrender poses and a weighted collapse replace the old billboard animation. Defeated bodies and dark residue remain in the room.

First-person hands, sleeves and a visible body use the same anatomical mesh and skinning pipeline. The fingers curl, the support hand moves during reloading, interactions reach forward, and a modeled flashlight accompanies the pistol and lowered weapon. Weapon parts animate, metal edges are beveled, and recoil returns to the mouse aim baseline. Close walls lower the weapon.

Movement uses a 3.65 m/s walk and 6.4 m/s sprint, acceleration and braking, distance-timed footsteps, restrained camera sway, buffered jumps and coyote time. Full shoulder clearance prevents standing into a ceiling. Nonfatal hits add flinch and screen feedback while movement remains controllable.

Worn Poly Haven furniture replaces the old chair/table/sofa placeholders. Dining rooms, sleeping rooms and lounges contain cloth curtains, rugs, shelves, books, cups, plates, bottles, lamps, bags, beds and fireplaces. Repeated small details are batched by floor. Furniture textures include normal and roughness maps.

A skippable first-person opening raises the viewpoint from the floor into play. Letterboxing, focus blur, film grain, subdued color grading and subtitles support the cinematic framing. The in-game HUD is smaller and quieter; the title and pause menus retain the original angular red-and-ivory identity. Press **Space, Enter or E** to skip an opening.

## Memory and accessibility

Four chapters develop obedience into remembrance. A failed attempt restarts the current chapter, retaining recovered fragments and witnesses. The photograph, evacuation list and later wristband lead to the final choice. Nothing rewrites the historical event. Both conclusions can be revisited.

Settings include master/music volume, mouse sensitivity, reduced motion, story assist, subtitle duration and subtitle size. Reduced motion softens view movement and removes heat distortion. Story assist halves incoming damage. Dialogue is subtitled; there is no voice acting. Local saves use Godot's user data directory.

## Scope

This is a playable prototype. Characters use authored procedural skeletal animation and IK, not motion capture or a physical ragdoll. Weapons and many supporting props remain original procedural meshes. The opening uses screen-space focus blur rather than depth-buffer-based optical depth of field. Smoke is layered particles; fire spread is authored. Dialogue is subtitled without recorded voices.

Windows packaging is provided. Runtime checks and rendered inspection were performed with Godot on Linux; native Windows execution, hardware performance testing and broader human playtesting remain outstanding.

Open **Source/afterimage-game/project.godot** in Godot 4.5.1 to edit. Credits, licensing, implementation notes and validation are included.

## Exit hotfix — 0.9.1
Press E on the fire door itself to leave. The exit can be used from the corridor side; walking behind the door is no longer required. The jamb has hinge clearance. Earlier memories still require exit power; the final memory requires all three fragments.
