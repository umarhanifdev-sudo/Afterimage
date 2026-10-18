extends Node3D
var world: Node3D
var building: MemoryBuilding
var player: MemoryPlayer
var milo: MiloVoice
var hud: AfterimageHUD
var generation = 0
var transitioning = false
var ending_kind = "acceptance"
var atmosphere: ShaderMaterial
var cinematic_active = false
var cinematic_time = 0.0
var cinematic_duration = 10.0
var quitting = false
var effect_pools = {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	Input.use_accumulated_input = false
	var post = CanvasLayer.new()
	post.layer = 5
	add_child(post)
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere = ShaderMaterial.new()
	atmosphere.shader = load("res://shaders/atmosphere.gdshader")
	overlay.material = atmosphere
	post.add_child(overlay)
	var layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	hud = AfterimageHUD.new()
	hud.game = self
	layer.add_child(hud)
	show_title()
	if OS.get_cmdline_user_args().has("--smoke"):
		print("SMOKE VERSION ",ProjectSettings.get_setting("application/config/version")," SCORE_SECONDS ",Sound.reflection.stream.get_length())
		GameState.new_run()
		start_chapter()
		await get_tree().create_timer(1.5).timeout
		shutdown()

func clear_world():
	effect_pools.clear()
	generation += 1
	cinematic_active = false
	if is_instance_valid(hud): hud.letterbox = 0
	get_tree().paused = false
	player = null
	milo = null
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = Node3D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.025,.035,.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.52,.61,.73)
	env.ambient_light_energy = .15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(.15,.19,.25)
	env.fog_density = .018
	env_node.environment = env
	world.add_child(env_node)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-30,0)
	sun.light_energy = .035
	sun.light_color = Color(.6,.68,.8)
	sun.light_cull_mask = 1
	world.add_child(sun)

func show_title():
	transitioning = false
	clear_world()
	GameState.started = false
	building = MemoryBuilding.new()
	world.add_child(building)
	building.build(0)
	var camera = Camera3D.new()
	camera.near = .05
	camera.far = 70
	camera.position = Vector3(-4.0,1.8,2.0)
	world.add_child(camera)
	camera.look_at(Vector3(-4,1.7,23))
	camera.current = true
	Sound.tension = .15
	Sound.set_scene("title")
	hud.clear_dialogue()
	hud.set_mode("title")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func start_chapter(with_intro: bool = false):
	transitioning = false
	clear_world()
	GameState.started = true
	building = MemoryBuilding.new()
	world.add_child(building)
	building.build(GameState.chapter)
	milo = MiloVoice.new()
	world.add_child(milo)
	player = MemoryPlayer.new()
	player.game = self
	player.building = building
	player.milo = milo
	player.position = Vector3(-4,.08,2.5)
	world.add_child(player)
	spawn_shadows()
	hud.clear_dialogue()
	hud.chapter_time = 3.2
	hud.fade = 0
	hud.set_mode("play")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sound.start()
	Sound.set_scene("remembrance" if GameState.chapter==3 else "play")
	opening_lines(generation)
	if with_intro: begin_intro()

func spawn_shadows():
	var specs = [
		["sentinel_lobby",Vector3(-4,0,20),0,0],
		["runner_entry",Vector3(9,0,13),1,1],
		["guard_records",Vector3(4,4.5,18),0,0],
		["flanker_records",Vector3(-4,4.5,29),0,1],
		["stalker_assembly",Vector3(-4,9,28),0,2],
		["apex_resistance",Vector3(4,9,10),0,3],
		["sentinel_exit",Vector3(4,13.5,25),0,0]]
	if GameState.chapter>=1:
		specs[0][2] = 1
	if GameState.chapter>=2:
		specs[3][2] = 1
		specs[6][0] = "guard_exit"
	if GameState.chapter==3:
		specs = [["sentinel_lobby",Vector3(-4,0,20),1,0],["runner_records",Vector3(4,4.5,18),1,1],["witness_assembly",Vector3(-4,9,28),1,2],["guard_exit",Vector3(4,13.5,25),1,3]]
	for spec in specs:
		var e = ShadowSoldier.new()
		e.identity = spec[0]
		e.position = spec[1]+Vector3(0,.04,0)
		e.kind = spec[2]
		e.role = spec[3]
		e.game = self
		e.player = player
		e.building = building
		e.add_to_group("shadows")
		world.add_child(e)

func opening_lines(token):
	await get_tree().create_timer(.5,false).timeout
	if token!=generation:
		return
	match GameState.chapter:
		0:
			GameState.say("YOU","Hold me up, Milo. The exit is on the fourth floor. Anyone still here is a threat.")
			GameState.say("MILO","I've got the weapon. You tell me where to go.")
		1:
			GameState.say("MILO","That clock. Those hands were different. And this wasn't the weapon I had.")
			GameState.say("YOU","We have a rifle now. Same room. Same orders.")
		2:
			GameState.say("MILO","A heavier gun doesn't make you right. I remember their hands.")
			GameState.say("YOU","Don't look at their hands. Watch the doors.")
		3:
			GameState.say("MILO","There was no injured man. Only the voice I kept using to explain what I did.")
			GameState.say("MILO","I'm old now. This room is still burning. I need to remember all of it.")

func interact(item: Dictionary):
	if transitioning or item.used:
		return
	if item.has("door"):
		if item.door.identity=="fire_exit":
			interact({"id":"exit","used":false})
			return
		item.door.interact(player)
		return
	var id = str(item.id)
	if id.begins_with("charger"):
		GameState.toast("HOLD E TO TURN THE GENERATOR / THE NOISE CARRIES")
		return
	if id.begins_with("battery"):
		player.battery = minf(100,player.battery+40)
		item.used = true
		Sound.play("reload",.3)
		GameState.toast("FLASHLIGHT CELL / +40 CHARGE")
		return
	if id == "exit":
		if GameState.chapter == 3:
			if GameState.clues.size()<3:
				GameState.toast("FRAGMENTS %d / 3 — TAB TO CHECK THE JOURNAL"%GameState.clues.size())
				GameState.say("MILO","The photograph. The list. The wristband. I can't leave those pieces out again.",{"priority":0,"ttl":5,"key":"missing_fragments"})
				return
			pause_to("choice")
		elif not GameState.power_on:
			GameState.toast("NO POWER / EXIT CIRCUIT ON FLOOR 02")
			GameState.say("MILO","The lock is dead. The circuit panel is on the second floor. East corridor, past the stairs.",{"priority":0,"ttl":6,"key":"power_hint"})
		else:
			transition_chapter()
	elif id == "power":
		if GameState.chapter==3:
			GameState.say("MILO","It was never the lock that kept me here.")
		GameState.power_on = true
		building.exit_door.locked = false
		item.used = true
		GameState.toast("EXIT CIRCUIT RESTORED")
		Sound.play("reload",.5)
	elif id.begins_with("ammo"):
		if GameState.chapter<3:
			player.reserve += int(player.weapon.mag)*3
			item.used = true
			GameState.toast("AMMUNITION  /  +3 MAGAZINES")
			Sound.play("reload",.4)
		else:
			GameState.say("MILO","I don't need those anymore.",{"priority":0,"ttl":3,"key":"no_ammo_needed"})
	elif id.begins_with("health"):
		if GameState.health>=100:
			GameState.toast("NO DRESSING NEEDED")
			return
		GameState.health = minf(100,GameState.health+45)
		item.used = true
		GameState.toast("FIELD DRESSING  /  +45 HEALTH")
		Sound.play("reload",.3)
	else:
		item.used = true
		GameState.clue(id,str(item.line))
		Sound.play("memory",.4)

func transition_chapter():
	if transitioning:
		return
	transitioning = true
	hud.letterbox = 1.0
	player.locked = true
	player.release_inputs()
	var token = generation
	# Do not erase the last sentence under a two-second fade. Let the current
	# story beat finish, then give the threshold line its own readable hold.
	hud.dialogue_queue = hud.dialogue_queue.filter(func(entry): return entry.priority>0)
	GameState.say("MILO","The handle is warm. I remember this part.",{"key":"threshold","priority":3})
	while hud.has_dialogue():
		await get_tree().process_frame
		if token!=generation or quitting: return
	Sound.play("memory",.8)
	var tween = create_tween()
	tween.tween_property(hud,"fade",1.0,1.4)
	await tween.finished
	await get_tree().create_timer(.5).timeout
	if token!=generation:
		return
	GameState.chapter = mini(3,GameState.chapter+1)
	GameState.begin_chapter()
	start_chapter(true)

func player_died():
	GameState.deaths += 1
	GameState.save_checkpoint()
	call_deferred("pause_to","death")

func pause_to(mode: String):
	if is_instance_valid(player):
		player.release_inputs()
	get_tree().paused = true
	hud.set_mode(mode)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume():
	get_tree().paused = false
	hud.set_mode("play")
	recover_controls()

func recover_controls():
	if not is_instance_valid(player) or hud.mode!="play" or transitioning or quitting: return
	player.release_inputs()
	if not cinematic_active and GameState.health>0: player.locked = false
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if hud.mode=="play" and not get_tree().paused and event is InputEventMouseButton and event.pressed and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
		recover_controls()
		get_viewport().set_input_as_handled()
		return
	if cinematic_active and not get_tree().paused and event is InputEventKey and event.pressed and event.physical_keycode in [KEY_SPACE,KEY_ENTER,KEY_E]:
		finish_intro()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			if hud.mode=="play" and not get_tree().paused: call_deferred("recover_controls")
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE:
			if transitioning:
				return
			match hud.mode:
				"play": pause_to("pause")
				"pause": resume()
				"transcript": hud.set_mode("journal")
				"journal", "settings", "controls", "credits": on_ui("back")
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_TAB:
			if hud.mode == "play":
				hud.previous_mode = "play"
				pause_to("journal")
			elif hud.mode in ["journal","transcript"]:
				on_ui("back")
			get_viewport().set_input_as_handled()

func on_ui(id: String):
	match id:
		"quit": shutdown()
		"new":
			GameState.new_run()
			call_deferred("start_chapter",true)
		"continue":
			GameState.resume_run()
			call_deferred("start_chapter",true)
		"resume": resume()
		"retry":
			GameState.begin_chapter()
			call_deferred("start_chapter")
		"title":
			if GameState.started:
				GameState.save_checkpoint()
			call_deferred("show_title")
		"settings", "controls", "credits", "journal":
			if hud.mode!="transcript": hud.previous_mode = hud.mode
			hud.set_mode(id)
		"transcript": hud.set_mode("transcript")
		"back":
			if hud.previous_mode == "play":
				resume()
			else:
				hud.set_mode(hud.previous_mode)
		"volume":
			GameState.volume = 0.0 if GameState.volume>=.99 else minf(1,GameState.volume+.2)
			GameState.save_settings()
		"music":
			GameState.music_volume = 0.0 if GameState.music_volume>=.99 else minf(1,GameState.music_volume+.2)
			GameState.save_settings()
		"sensitivity":
			GameState.sensitivity += .0006
			if GameState.sensitivity>.0041:
				GameState.sensitivity = .001
			GameState.save_settings()
		"motion":
			GameState.reduced_motion = not GameState.reduced_motion
			GameState.save_settings()
		"difficulty":
			GameState.story_mode = not GameState.story_mode
			GameState.save_settings()
		"subtitle_time":
			GameState.subtitle_duration = 1.5 if GameState.subtitle_duration<1.1 else 1.0
			GameState.save_settings()
		"subtitle_size":
			GameState.large_subtitles = not GameState.large_subtitles
			GameState.save_settings()
		"accept", "insist":
			ending_kind = "acceptance" if id == "accept" else "rationalization"
			call_deferred("show_ending")
		"reconsider":
			hud.set_mode("choice")

func _process(_dt):
	# The cinematic and transition own locks only while active. Recover stale control
	# state after menus/window changes without overriding death or an intentional pause.
	if is_instance_valid(player) and hud.mode=="play" and not get_tree().paused and not cinematic_active and not transitioning and GameState.health>0:
		player.locked = false
		if not player.camera.is_current(): player.camera.make_current()
	if cinematic_active and not get_tree().paused:
		update_intro(_dt)
	elif not transitioning:
		hud.letterbox = move_toward(hud.letterbox,0,_dt*1.5)

	if is_instance_valid(player) and hud.mode == "play":
		var danger = 0.0
		for e in get_tree().get_nodes_in_group("shadows"):
			if e.alive and e.kind==0 and e.can_see and not e.surrendered:
				danger = maxf(danger,1.0-minf(e.global_position.distance_to(player.global_position)/25,1))
		Sound.tension = danger

	if is_instance_valid(atmosphere):
		atmosphere.set_shader_parameter("heat",player.heat if is_instance_valid(player) else .0)
		atmosphere.set_shader_parameter("motion",.0 if GameState.reduced_motion else 1.0)

func budget_effect(node: Node, category: String, limit: int):
	var pool: Array = effect_pools.get(category,[])
	pool = pool.filter(func(n):return is_instance_valid(n) and not n.is_queued_for_deletion())
	while pool.size()>=limit:
		pool.pop_front().queue_free()
	pool.append(node)
	effect_pools[category] = pool

func tracer(from: Vector3, to: Vector3, color: Color):
	if not is_instance_valid(world):
		return
	var m = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	m.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	m.material_override = mat
	world.add_child(m)
	budget_effect(m,"tracers",12)
	var lifetime = m.create_tween()
	lifetime.tween_interval(.07)
	lifetime.tween_callback(m.queue_free)

func shot_smoke(pos: Vector3):
	if is_instance_valid(player) and player.global_position.distance_squared_to(pos)>324: return
	var p = building.particles(pos,"smoke_01",3,.32,Color(.43,.42,.37,.23),.13,Vector3(0,.5,0))
	p.one_shot = true
	budget_effect(p,"muzzle_smoke",8)
	p.emission_box_extents = Vector3.ONE*.025
	p.explosiveness = 1
	p.preprocess = 0
	p.restart()
	var lifetime = p.create_tween()
	lifetime.tween_interval(1.0)
	lifetime.tween_callback(p.queue_free)

func eject_shell(pos: Vector3, aim: Basis):
	if is_instance_valid(player) and player.global_position.distance_squared_to(pos)>196: return
	var shell = RigidBody3D.new()
	shell.collision_layer = 0
	shell.collision_mask = 1
	shell.mass = .015
	shell.position = pos
	shell.linear_velocity = aim.x*randf_range(2.1,3.4)+Vector3.UP*2
	shell.angular_velocity = Vector3(13,17,7)
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = .018
	cyl.bottom_radius = .018
	cyl.height = .065
	cyl.radial_segments = 8
	mesh.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(.52,.36,.12)
	mat.metallic = .8
	mat.roughness = .35
	mesh.material_override = mat
	shell.add_child(mesh)
	var c = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = .025
	c.shape = shape
	shell.add_child(c)
	world.add_child(shell)
	budget_effect(shell,"casings",16)
	var lifetime = shell.create_tween()
	lifetime.tween_interval(.42)
	var shell_ref = weakref(shell)
	lifetime.tween_callback(func():
		var live = shell_ref.get_ref()
		if live: Sound.at("shell",live.global_position,.18))
	lifetime.tween_interval(.58)
	lifetime.tween_property(shell,"freeze",true,0)
	lifetime.tween_interval(1.5)
	lifetime.tween_callback(shell.queue_free)

func impact(pos: Vector3, normal: Vector3, shadow: bool):
	var p = building.particles(pos+normal*.025,"smoke_01",4,.35,Color(.045,.04,.035,.75) if shadow else Color(.38,.34,.27,.45),.19,Vector3(0,.8,0))
	p.one_shot = true
	p.explosiveness = 1
	p.preprocess = 0
	p.emission_box_extents = Vector3.ONE*.035
	budget_effect(p,"impacts",12)
	p.direction = normal
	p.spread = 40
	p.gravity = Vector3(0,-1,0)
	p.restart()
	var lifetime = p.create_tween()
	lifetime.tween_interval(.7)
	lifetime.tween_callback(p.queue_free)
	if shadow: return
	var mark = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(.11,.11)
	mark.mesh = quad
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/particles/smoke_01.png")
	mat.albedo_color = Color(.015,.013,.01,.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mark.material_override = mat
	mark.position = pos+normal*.008
	world.add_child(mark)
	budget_effect(mark,"marks",40)
	mark.look_at(pos+normal,Vector3.RIGHT if absf(normal.y)>.95 else Vector3.UP)
	var mark_lifetime = mark.create_tween()
	mark_lifetime.tween_interval(18)
	mark_lifetime.tween_callback(mark.queue_free)

func show_ending():
	clear_world()
	GameState.started = false
	building = MemoryBuilding.new()
	world.add_child(building)
	building.box(Vector3(2,-.15,2),Vector3(18,.3,18),Color(.32,.36,.37),false)
	building.box(Vector3(2,2.5,6.0),Vector3(18,5,.3),Color(.32,.41,.43),false)
	building.box(Vector3(6,2.5,2),Vector3(.3,5,9),Color(.29,.38,.39),false)
	building.make_bed(Vector3(2,0,2))
	var elder = HumanRig.new()
	world.add_child(elder)
	elder.setup("elder")
	elder.apply_layer(elder.model,1)
	elder.position = Vector3(2,.96,1.27)
	elder.rotation = Vector3(-PI/2,PI,0)
	for side in ["L","R"]:
		elder.solve_limb("upperarm01_"+side,"lowerarm01_"+side,"wrist_"+side,Vector3(.12 if side=="L" else -.12,1.05,.20),Vector3(1 if side=="L" else -1,0,0),Quaternion.from_euler(Vector3(PI/2,0,0)))
		elder.bend_fingers(side,.15)
	RoomProps.soft(building,Vector3(2,1.03,1.8),Vector3(1.2,.20,1.5),Color(.28,.36,.34),.08)
	RoomProps.imported(building,"table",Vector3(3.7,0,2.5),PI/2,Vector3(.7,1.5,.8))
	RoomProps.cup(building,Vector3(3.7,.83,2.5))
	building.box(Vector3(4.2,2.8,5.8),Vector3(2.6,2.7,.05),Color(.62,.72,.69),false).material_override = building.material(Color(.62,.72,.69),.6)
	building.box(Vector3(4.2,2.8,5.7),Vector3(.07,2.7,.1),Color(.3,.38,.39),false)
	building.light(Vector3(3.7,3.6,3.7),Color(.74,.84,.83),2.7,9)
	building.light(Vector3(0,2.7,0),Color(.88,.65,.43),1.3,7)
	var camera = Camera3D.new()
	camera.near = .05
	camera.far = 70
	camera.position = Vector3(.2,2.3,.1)
	world.add_child(camera)
	camera.look_at(Vector3(2,1.35,2.1))
	camera.h_offset = -1.65
	camera.current = true
	Sound.tension = 0
	Sound.set_scene("ending")
	hud.clear_dialogue()
	hud.ending = ending_kind
	hud.set_mode("ending")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and hud.mode=="play" and not transitioning:
		pause_to("pause")
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		shutdown()

func shutdown():
	if quitting: return
	quitting = true
	if GameState.started: GameState.save_checkpoint()
	Sound.shutdown()
	get_tree().paused = false
	await get_tree().create_timer(.35).timeout
	get_tree().quit()

func shadow_residue(pos: Vector3):
	var residue = MeshInstance3D.new()
	var disk = CylinderMesh.new()
	disk.top_radius = .56
	disk.bottom_radius = .56
	disk.height = .005
	disk.radial_segments = 24
	residue.mesh = disk
	residue.material_override = building.material(Color(.016,.015,.014))
	residue.position = pos+Vector3(0,.012,0)
	residue.scale = Vector3(.8,1,1.7)
	world.add_child(residue)
	var dust = building.particles(pos+Vector3(0,.25,0),"smoke_04",10,1.1,Color(.06,.055,.045,.4),.4,Vector3(0,.3,0))
	dust.one_shot = true
	dust.explosiveness = .8
	dust.preprocess = 0
	dust.restart()
	var lifetime = dust.create_tween()
	lifetime.tween_interval(1.4)
	lifetime.tween_callback(dust.queue_free)

func begin_intro():
	cinematic_active = true
	cinematic_time = 0.0
	cinematic_duration = 10.0 if GameState.chapter==0 else 5.8
	player.locked = true
	player.release_inputs()
	hud.letterbox = 1.0
	hud.chapter_time = 0
	hud.fade = 1
	Sound.play("heart",.5)
	update_intro(0)

func update_intro(dt: float):
	cinematic_time += dt
	var t = clampf(cinematic_time/cinematic_duration,0,1)
	var lift = smoothstep(.13,.88,t)
	player.update_view(dt,0,false)
	player.head.position.y = lerpf(.48,1.65,lift)
	player.head.rotation.x = lerpf(-.28,0,lift)
	player.camera_tilt.z = lerpf(.11,0,lift)*(.2 if GameState.reduced_motion else 1.0)
	player.yaw = PI+sin(t*PI)*.10
	player.rotation.y = player.yaw
	player.camera.fov = lerpf(67.0,80.0,smoothstep(.72,1,t))
	player.sync_camera()
	hud.fade = maxf(0,1-cinematic_time/1.5)
	atmosphere.set_shader_parameter("focus_blur",(1-lift)*1.1)
	if cinematic_time>=cinematic_duration: finish_intro()

func finish_intro():
	if not cinematic_active: return
	cinematic_active = false
	player.locked = false
	player.velocity = Vector3.ZERO
	player.release_inputs()
	player.head.position.y = 1.65
	player.head.rotation.x = player.pitch
	player.yaw = PI
	player.rotation.y = PI
	player.camera_tilt = Vector3.ZERO
	player.sync_camera()
	player.camera.fov = 80
	if hud.mode=="play" and not get_tree().paused: recover_controls()
	hud.fade = 0
	hud.chapter_time = 3.2
	atmosphere.set_shader_parameter("focus_blur",0.0)
