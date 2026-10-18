class_name MemoryPlayer
extends CharacterBody3D
var game
var building: MemoryBuilding
var milo: MiloVoice
var camera: Camera3D
var head: Node3D
var gun: Node3D
var lamp: SpotLight3D
var muzzle: OmniLight3D
var flash: MeshInstance3D
var capsule: CollisionShape3D
var held = {}
var firing = false
var ads = false
var locked = false
var yaw = PI
var pitch = 0.0
var stamina = 100.0
var slide_time = 0.0
var slide_dir = Vector3.ZERO
var crouched = false
var jump_buffer = 0.0
var coyote = 0.0
var ammo = 0
var reserve = 0
var reload_time = 0.0
var fire_time = 0.0
var weapon: Dictionary
var target = null
var interaction: Dictionary = {}
var recoil = 0.0
var sway = Vector2.ZERO
var bob = 0.0
var land_kick = 0.0
var step_timer = 0.0
var flash_time = 0.0
var invulnerable = 0.0
var since_hurt = 0.0
var damage_flash = 0.0
var hitmarker = 0.0
var was_grounded = true
var last_y_velocity = 0.0
var time_alive = 0.0
var battery = 100.0
var light_on = true
var light_toggle = 0.0
var lamp_pivot: Node3D
var kick_pitch = 0.0
var kick_velocity = 0.0
var shake = 0.0
var charging = 0.0
var charge_sound = 0.0
var light_disruption = 0.0
var heat = 0.0
var hands: HumanRig
var body_model: HumanRig
var weapon_model: ServiceWeapon
var interaction_time = 0.0
var hit_flinch = 0.0
var near_wall = 0.0
var distance_walked = 0.0
var last_step = 0.0
var flashlight_model: Node3D
var camera_tilt = Vector3.ZERO
var previous_position = Vector3.ZERO
var physics_position = Vector3.ZERO
var eye_height = 1.65
var view_sprint = false
var wall_check_time = 0.0
var wall_blocked = false
var right_grip_target = Transform3D.IDENTITY
var left_grip_target = Transform3D.IDENTITY


func _ready():
	collision_layer = 4
	collision_mask = 1|2
	floor_snap_length = .38
	floor_constant_speed = true
	safe_margin = .025
	floor_max_angle = deg_to_rad(46)
	capsule = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = .32
	shape.height = 1.8
	capsule.shape = shape
	capsule.position.y = .9
	add_child(capsule)
	head = Node3D.new()
	head.position.y = 1.65
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 80
	camera.near = .05
	camera.far = 70
	head.add_child(camera)
	camera.current = true
	camera.top_level = true
	previous_position = global_position
	physics_position = global_position
	sync_camera()
	rotation.y = yaw
	lamp = SpotLight3D.new()
	lamp.spot_range = 19
	lamp.spot_angle = 29
	lamp.spot_attenuation = .65
	lamp.light_energy = 4.2
	lamp.light_color = Color(.91,.89,.78)
	lamp.light_cull_mask = 1
	lamp.shadow_enabled = true
	lamp.position = Vector3(.12,-.08,-.1)
	lamp_pivot = Node3D.new()
	camera.add_child(lamp_pivot)
	lamp_pivot.add_child(lamp)
	gun = Node3D.new()
	camera.add_child(gun)
	weapon = GameState.weapon()
	ammo = int(weapon.mag)
	reserve = int(weapon.reserve)
	build_weapon()
	hands = HumanRig.new()
	camera.add_child(hands)
	hands.setup("arms")
	hands.rotation.y = PI
	# First-person shoulders sit forward enough to reach the fore-end without
	# stretching the mesh or silently clamping the support wrist short of it.
	hands.position = Vector3(0,-1.65,-.48)
	body_model = HumanRig.new()
	add_child(body_model)
	body_model.setup("body")
	body_model.rotation.y = PI
	body_model.position = Vector3(0,0,.18)
	flashlight_model = Node3D.new()
	lamp_pivot.add_child(flashlight_model)
	flashlight_model.position = Vector3(-.23,-.19,-.39)
	var housing = ServiceWeapon.new()
	flashlight_model.add_child(housing)
	var metal = housing.mat(Color(.07,.08,.072),.65,.4)
	housing.barrel(Vector3.ZERO,.033,.19,metal)
	housing.barrel(Vector3(0,0,-.105),.046,.055,metal)
	var glass = housing.mat(Color(.65,.7,.56),.2,.18)
	glass.emission_enabled = true
	glass.emission = Color(.18,.18,.12)
	housing.barrel(Vector3(0,0,-.135),.037,.006,glass)
	for i in range(6): housing.barrel(Vector3(0,0,.06-i*.022),.035,.004,metal)

	var key = OmniLight3D.new()
	key.position = Vector3(-.5,.2,-.1)
	key.light_cull_mask = 2
	key.omni_range = 3
	key.light_energy = 1.15
	key.light_color = Color(.8,.85,.93)
	camera.add_child(key)
	var fill = OmniLight3D.new()
	fill.position = Vector3(.6,-.4,-.5)
	fill.light_cull_mask = 2
	fill.omni_range = 2
	fill.light_energy = .25
	fill.light_color = Color(1,.47,.25)
	camera.add_child(fill)

func build_weapon():
	gun.position = Vector3(.24,-.19,-.50)
	gun.scale = Vector3.ONE*.9
	if GameState.chapter >= 3:
		return
	weapon_model = ServiceWeapon.new()
	gun.add_child(weapon_model)
	weapon_model.build(GameState.chapter)
	muzzle = OmniLight3D.new()
	muzzle.position = Vector3(0,.05,[-.37,-.73,-.73][GameState.chapter])
	muzzle.light_color = Color(1,.67,.24)
	muzzle.omni_range = 5
	muzzle.light_energy = 0
	gun.add_child(muzzle)
	flash = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(.24,.24)
	flash.mesh = quad
	flash.position = muzzle.position
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/particles/muzzle_01.png")
	mat.albedo_color = Color(1,.7,.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash.material_override = mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gun.add_child(flash)
	flash.visible = false

func style_weapon(node: Node, mat: ShaderMaterial):
	if node is MeshInstance3D:
		node.material_override = mat
		node.layers = 2
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		style_weapon(child,mat)

func _input(event):
	if locked or get_tree().paused or not GameState.started or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion = event.screen_relative if event.screen_relative.length_squared()>0 else event.relative
		yaw -= motion.x*GameState.sensitivity
		pitch = clampf(pitch-motion.y*GameState.sensitivity,-1.4,1.4)
		sway += motion*.0007
		head.rotation.x = pitch+kick_pitch+hit_flinch*.006
		sync_camera()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			firing = event.pressed
			if firing:
				try_fire()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			ads = event.pressed
	elif event is InputEventKey:
		held[event.physical_keycode] = event.pressed
		if event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_SPACE:
					jump_buffer = .14
				KEY_C, KEY_CTRL:
					if is_on_floor() and Vector2(velocity.x,velocity.z).length()>5.2:
						start_slide()
				KEY_R:
					start_reload()
				KEY_Q:
					if GameState.chapter<3:
						GameState.lowered = not GameState.lowered
						Sound.play("ui",.3)
				KEY_F:
					light_on = not light_on
					light_toggle = .28
					Sound.play("switch",.45)
				KEY_E:
					if not interaction.is_empty():
						interaction_time = .65
						game.interact(interaction)

func down(key) -> bool:
	return bool(held.get(key,false))

func release_inputs():
	held.clear()
	firing = false
	ads = false
	jump_buffer = 0

func start_slide():
	if stamina<15 or slide_time>0:
		return
	slide_time = .65
	stamina -= 15
	slide_dir = Vector3(velocity.x,0,velocity.z).normalized()
	if slide_dir.length()<.1:
		slide_dir = -global_transform.basis.z
	Sound.play("slide",.4)

func _physics_process(dt):
	if locked:
		return
	if global_position.distance_squared_to(physics_position)>4:
		previous_position = global_position
	else:
		previous_position = physics_position
	rotation.y = yaw
	interaction_time = maxf(0,interaction_time-dt)
	hit_flinch = move_toward(hit_flinch,0,dt*3)
	fire_time = maxf(0,fire_time-dt)
	invulnerable = maxf(0,invulnerable-dt)
	since_hurt += dt
	damage_flash = maxf(0,damage_flash-dt*.8)
	hitmarker = maxf(0,hitmarker-dt)
	if reload_time>0:
		reload_time -= dt
		if reload_time<=0:
			var needed = mini(int(weapon.mag)-ammo,reserve)
			ammo += needed
			reserve -= needed
	if weapon.auto and firing:
		try_fire()
	var input = Vector2(float(down(KEY_D) or down(KEY_RIGHT))-float(down(KEY_A) or down(KEY_LEFT)),float(down(KEY_S) or down(KEY_DOWN))-float(down(KEY_W) or down(KEY_UP))).normalized()
	var dir = global_transform.basis*Vector3(input.x,0,input.y)
	var want_crouch = down(KEY_C) or down(KEY_CTRL) or slide_time>0
	if crouched and not want_crouch:
		# Check the entire upper body, including the shoulders, before standing.
		var query = PhysicsShapeQueryParameters3D.new()
		var upper_body = BoxShape3D.new()
		upper_body.size = Vector3(.63,.70,.63)
		query.shape = upper_body
		query.transform = Transform3D(Basis.IDENTITY,global_position+Vector3(0,1.445,0))
		query.collision_mask = 1
		query.exclude = [get_rid()]
		want_crouch = not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
	crouched = want_crouch
	capsule.shape.height = 1.1 if crouched else 1.8
	capsule.position.y = .55 if crouched else .9
	var sprint = down(KEY_SHIFT) and input.y<0 and stamina>0 and not ads and not crouched
	var speed = 6.4 if sprint else (1.8 if crouched else (2.4 if ads and not GameState.lowered else 3.65))
	stamina = clampf(stamina+dt*(-12 if sprint else 20),0,100)
	if is_on_floor():
		coyote = .12
	else:
		coyote -= dt
	jump_buffer -= dt
	if jump_buffer>0 and coyote>0:
		velocity.y = 4.8
		jump_buffer = 0
		coyote = 0
		slide_time = 0
		Sound.play("land",.25)
	else:
		velocity.y -= 19.5*dt
	if slide_time>0:
		slide_time -= dt
		velocity.x = slide_dir.x*(4.2+3.3*slide_time)
		velocity.z = slide_dir.z*(4.2+3.3*slide_time)
	else:
		var acceleration = (24.0 if input.length()<.1 else 21.0) if is_on_floor() else 5.5
		velocity.x = move_toward(velocity.x,dir.x*speed,dt*acceleration)
		velocity.z = move_toward(velocity.z,dir.z*speed,dt*acceleration)
	last_y_velocity = velocity.y
	move_and_slide()
	if not was_grounded and is_on_floor() and last_y_velocity< -4:
		land_kick = minf(.09,-last_y_velocity*.008)
		Sound.play("land",.45)
	was_grounded = is_on_floor()
	var horizontal_speed = Vector2(velocity.x,velocity.z).length()
	if is_on_floor() and horizontal_speed>.6:
		distance_walked += horizontal_speed*dt
		var step_length = 1.55 if sprint else (.95 if crouched else 1.35)
		if distance_walked-last_step>=step_length:
			last_step = distance_walked
			Sound.footstep(absf(global_position.x)<2.1 and global_position.z>11.5 and global_position.z<22.2,.12 if crouched else (.38 if sprint else .25))
	for hazard in building.hazards:
		if absf(position.y-hazard.y)<1.6 and Vector2(position.x-hazard.x,position.z-hazard.z).length()<1.12:
			hurt(6)
	if since_hurt>8 and GameState.health<45:
		GameState.health = minf(45,GameState.health+dt*5)
	physics_position = global_position
	view_sprint = sprint
	update_light(dt)
	update_target(dt)

func _process(dt):
	# Rotation follows raw mouse input at render rate. Only body translation is
	# interpolated between fixed collision steps; mouse aim is never smoothed.
	if not locked and is_physics_processing():
		time_alive += dt
		update_view(dt,Vector2(velocity.x,velocity.z).length(),view_sprint)
	sync_camera()

func sync_camera():
	if not is_instance_valid(camera): return
	var origin = global_position
	if is_physics_processing() and not locked and global_position.distance_squared_to(physics_position)<.001:
		origin = previous_position.lerp(physics_position,Engine.get_physics_interpolation_fraction())
	camera.global_transform = Transform3D(Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,head.rotation.x)*Basis.from_euler(camera_tilt),origin+Vector3.UP*head.position.y)

func update_view(dt, speed, sprint):
	rotation.y = yaw
	# Substeps keep the recoil spring stable during a slow render frame.
	var steps = maxi(1,ceili(dt*120))
	for i in range(steps):
		var step = dt/steps
		kick_velocity += (-kick_pitch*115-kick_velocity*18)*step
		kick_pitch = clampf(kick_pitch+kick_velocity*step,0,.16)
	head.rotation.x = pitch+kick_pitch+hit_flinch*.006
	shake = move_toward(shake,0,dt*1.8)
	camera_tilt.x = sin(time_alive*17)*shake*.003*(.2 if GameState.reduced_motion else 1.0)
	camera_tilt.y = sin(time_alive*13)*shake*.002*(.2 if GameState.reduced_motion else 1.0)
	bob = distance_walked*PI/1.35
	land_kick = move_toward(land_kick,0,dt*.8)
	var motion = .23 if GameState.reduced_motion else 1.0
	var bob_y = sin(bob*2)*.008*minf(speed/4,1)*motion if is_on_floor() else 0.0
	head.position.y = lerpf(head.position.y,(.99 if crouched else 1.65)+bob_y-land_kick*motion,minf(dt*12,1))
	camera_tilt.z = lerpf(camera_tilt.z,(-velocity.dot(global_transform.basis.x)*.001+(0.012 if slide_time>0 else 0)+hit_flinch*.008)*motion,1-exp(-dt*7))
	sync_camera()
	camera.fov = lerpf(camera.fov,60.0 if ads and not GameState.lowered else (84.0 if sprint and not GameState.reduced_motion else 80.0),minf(dt*8,1))
	recoil = lerpf(recoil,0,minf(dt*13,1))
	sway = sway.lerp(Vector2.ZERO,minf(dt*9,1)).limit_length(.09)
	var lowered = GameState.lowered or sprint
	var base = Vector3(0,[-.084,-.105,-.10,0][GameState.chapter],-.4) if ads and not lowered else Vector3(.24,-.19,-.50)
	if lowered:
		base += Vector3(.08,-.30,.1)
	if reload_time>0:
		base += Vector3(.04,-.08,.02)
	wall_check_time -= dt
	if wall_check_time<=0:
		wall_check_time = .05
		var wall_ray = PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*.95,1)
		wall_blocked = not get_world_3d().direct_space_state.intersect_ray(wall_ray).is_empty()
	near_wall = lerpf(near_wall,1.0 if wall_blocked else 0.0,1-exp(-dt*10))
	base += Vector3(0,-near_wall*.13,near_wall*.15)

	base += Vector3(-sway.x+sin(bob*.5)*.009*motion,-sway.y+absf(sin(bob))*.009*motion,recoil*.055)
	gun.position = gun.position.lerp(base,minf(dt*14,1))
	gun.rotation = Vector3(recoil*.09 + (-.5 if lowered else 0)-near_wall*.4,-sway.x,(-.20 if reload_time>0 else 0)+sway.x)
	var reload_progress = 1-reload_time/float(weapon.reload) if reload_time>0 else 0.0
	var reach = sin((1-interaction_time/.65)*PI) if interaction_time>0 else 0.0
	update_grips(reload_progress,reach)
	body_model.position.y = -.5 if crouched else 0.0
	body_model.animate_body(dt,speed)
	if is_instance_valid(weapon_model): weapon_model.animate_parts(reload_progress,recoil)

	flash_time = maxf(0,flash_time-dt)
	if is_instance_valid(muzzle):
		muzzle.light_energy = 1.3 if flash_time>0 else 0
		flash.visible = flash_time>0
		flash.rotation.z += dt*12

func update_grips(reload_progress: float, reach: float):
	hands.position.y = -1.65+minf(0,gun.position.y+.19)*.85
	hands.position.z = -.55 if GameState.chapter in [1,2] else -.48
	var empty = GameState.chapter>=3
	var torch = empty or GameState.chapter==0 or GameState.lowered
	flashlight_model.visible = torch and reload_progress<=0 and reach<.08
	var right_curl = .08 if empty else 1.0
	var left_curl = 1.0
	if not empty:
		right_grip_target = weapon_model.grip_transform("R")
		left_grip_target = weapon_model.grip_transform("L")
	else:
		right_grip_target = camera.global_transform*Transform3D(ServiceWeapon.palm_frame(Vector3.UP,Vector3.FORWARD),Vector3(.25,-.43,-.47))
	if torch:
		left_grip_target = flashlight_model.global_transform*Transform3D(ServiceWeapon.palm_frame(Vector3.FORWARD,Vector3.UP),Vector3(-.028,-.024,.035))
	if reload_progress>0:
		# The firing hand stays planted. The support hand follows the magazine
		# down and back, then returns to its own fore-end grip.
		var envelope = sin(reload_progress*PI)
		var reload_grip = gun.global_transform*Transform3D(ServiceWeapon.palm_frame(Vector3.BACK,Vector3.RIGHT),Vector3(-.035,-.23-envelope*.12,-.14))
		left_grip_target = left_grip_target.interpolate_with(reload_grip,smoothstep(0,.18,reload_progress)*(1-smoothstep(.78,1,reload_progress)))
		left_curl = .75
	elif reach>0:
		left_grip_target.origin += camera.global_basis*Vector3(.04,reach*.04,-reach*.09)
		left_curl = 1-reach
	hands.animate_grips(right_grip_target,left_grip_target,right_curl,left_curl)

func aim_ray(distance: float = 45.0) -> Dictionary:
	sync_camera()
	var from = camera.global_position
	var to = from+shot_direction()*distance
	var q = PhysicsRayQueryParameters3D.create(from,to,1|2)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

func update_target(dt):
	target = null
	var hit = aim_ray(25)
	if not hit.is_empty() and hit.collider is ShadowSoldier:
		target = hit.collider
		if lamp.visible and target.alive and camera.global_position.distance_to(target.global_position)<lamp.spot_range:
			target.observe(dt)
	interaction = {}
	var best = 3.1
	if not hit.is_empty() and hit.collider.has_meta("door") and hit.position.distance_to(camera.global_position)<3.1:
		var door = hit.collider.get_meta("door")
		interaction = {"id":door.identity,"prompt":door.prompt(),"pos":door.centre(),"used":false,"door":door}
		best = hit.position.distance_to(camera.global_position)
	for item in building.interactables:
		if item.used:
			continue
		var delta = item.pos-camera.global_position
		var distance = delta.length()
		if distance>best or distance<.05:
			continue
		if delta.normalized().dot(-camera.global_transform.basis.z)<.78:
			continue
		var q = PhysicsRayQueryParameters3D.create(camera.global_position,item.pos,1)
		var block = get_world_3d().direct_space_state.intersect_ray(q)
		if not block.is_empty() and block.position.distance_to(item.pos)>.4:
			continue
		best = distance
		interaction = item

func try_fire():
	if locked or fire_time>0 or reload_time>0:
		return
	if GameState.lowered and GameState.chapter<3:
		GameState.lowered = false
		fire_time = .25
		return
	var center = aim_ray(45)
	var intended = center.collider if not center.is_empty() and center.collider is ShadowSoldier else null
	if not milo.permits(intended):
		fire_time = .4
		return
	if ammo<=0:
		Sound.play("empty",.5)
		fire_time = .3
		start_reload()
		return
	ammo -= 1
	GameState.shots += 1
	fire_time = float(weapon.interval)
	recoil += float(weapon.recoil)*(0.55 if ads else 1.0)
	kick_velocity += float(weapon.recoil)*.65*(.65 if ads else 1.0)
	shake = minf(1,shake+.35*float(weapon.recoil))
	yaw += randf_range(-.003,.003)*float(weapon.recoil)
	flash_time = .055
	Sound.play(weapon.sound,.8)
	game.eject_shell(gun.global_position+camera.global_basis.x*.1,camera.global_basis)
	game.shot_smoke(muzzle.global_position)
	for enemy in get_tree().get_nodes_in_group("shadows"):
		enemy.hear_shot(global_position)
	var from = camera.global_position
	var spread = (.045 if ads else .075) if int(weapon.pellets)>1 else (.006 if ads else .017)
	spread += Vector2(velocity.x,velocity.z).length()*.0015
	for i in range(int(weapon.pellets)):
		var dir = shot_direction()+camera.global_transform.basis.x*randf_range(-spread,spread)+camera.global_transform.basis.y*randf_range(-spread,spread)
		var end = from+dir.normalized()*60
		var q = PhysicsRayQueryParameters3D.create(from,end,1|2)
		q.exclude = [get_rid()]
		var hit = get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			end = hit.position
			if hit.collider is ShadowSoldier:
				var headshot = hit.position.y-hit.collider.global_position.y>(2.14 if hit.collider.role>=2 else 1.72)
				hit.collider.take_hit(float(weapon.damage)*(1.8 if headshot else 1.0))
				hitmarker = .13
				Sound.play("hit",.3)
			game.impact(end,hit.normal,hit.collider is ShadowSoldier)
		if i<3:
			game.tracer(muzzle.global_position,end,Color(1,.75,.37))

func start_reload():
	if reload_time>0 or ammo>=int(weapon.mag) or reserve<=0 or GameState.chapter>=3:
		return
	reload_time = float(weapon.reload)
	Sound.play("reload",.5)

func hurt(amount: float):
	if invulnerable>0 or locked or GameState.health<=0:
		return
	invulnerable = .45
	since_hurt = 0
	GameState.health = maxf(0,GameState.health-amount*(.5 if GameState.story_mode else 1.0))
	damage_flash = .48
	hit_flinch = 1.0
	shake = maxf(shake,.3)
	Sound.play("heart",.55)
	if GameState.health<=0:
		locked = true
		game.player_died()

func update_light(dt: float):
	light_toggle = maxf(0,light_toggle-dt)
	light_disruption = maxf(0,light_disruption-dt)
	if light_on and battery>0:
		battery = maxf(0,battery-dt*.46)
	lamp.visible = light_on
	var failing = battery<18 or light_disruption>0
	var flicker = 1.0-(.30 if light_disruption>0 else .12)*(.5+.5*sin(time_alive*4.5)) if failing else 1.0
	lamp.light_energy = (4.2 if battery>0 else .55)*flicker*(1-light_toggle*2.8)
	lamp.spot_range = 19 if battery>0 else 5
	lamp_pivot.rotation = lamp_pivot.rotation.lerp(Vector3(-sway.y*2-light_toggle*.8,-sway.x*2,0),minf(1,dt*7))
	charging = 0
	charge_sound -= dt
	if down(KEY_E) and not interaction.is_empty():
		if interaction.has("door"):
			interaction.door.force(dt,self)
			charging = interaction.door.resistance/1.6 if interaction.door.jammed else 0
		elif str(interaction.id).begins_with("charger"):
			battery = minf(100,battery+dt*23)
			charging = battery/100
			if charge_sound<=0 and battery<100:
				charge_sound = .7
				Sound.play("charge",.4)
				for e in get_tree().get_nodes_in_group("shadows"): e.hear_noise(global_position,14)
	heat = 0
	for h in building.hazards:
		if absf(position.y-h.y)<2:
			heat = maxf(heat,clampf(1-position.distance_to(h)/5,0,1))

func looking_at(pos: Vector3, cone: float = .92) -> bool:
	var delta = pos-camera.global_position
	if delta.length()>.1 and delta.normalized().dot(-camera.global_basis.z)<cone: return false
	var q = PhysicsRayQueryParameters3D.create(camera.global_position,pos,1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func shot_direction() -> Vector3:
	sync_camera()
	var size = get_viewport().get_visible_rect().size
	var ui_scale = minf(size.x/1280,size.y/720)
	return camera.project_ray_normal(size*.5+Vector2(0,-kick_pitch*220*ui_scale))
