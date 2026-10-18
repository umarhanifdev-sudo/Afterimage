class_name ShadowSoldier
extends CharacterBody3D
# Hostility is a remembered intention, never inferred from the silhouette's shape.
enum Kind { HOSTILE, AFRAID, FLEEING }
enum State { IDLE, SEARCH, ADVANCE, STRAFE, WINDUP, RECOVER, FLEE, SURRENDER, DEAD, BURST, RELOAD }
var kind = Kind.HOSTILE
var state = State.IDLE
var role = 0
var identity = ""
var player
var building: MemoryBuilding
var game
var hp = 75.0
var alive = true
var revealed = false
var surrendered = false
var observed = 0.0
var trust = 0.0
var cooldown = 1.4
var windup = 0.0
var suppressed = 0.0
var last_heard = Vector3.ZERO
var has_heard = false
var last_fire = -100.0
var aim_point = Vector3.ZERO
var spawn_point = Vector3.ZERO
var path = PackedVector3Array()
var route_goal = Vector3.INF
var lit_time = 0.0
var pulse_timer = 7.0
var pulse_windup = 0.0
var whisper_timer = 4.0
var under_light = false
var is_watched = false
var hurt_reaction = 0.0
var speed_scale = 1.0
var path_timer = 0.0
var time_alive = 0.0
var dead_time = 0.0
var seed = 0.0
var visual: SoldierRig
var shadow_mat: ShaderMaterial
var tell_light: OmniLight3D
var can_see = false
var facing = Vector3(0,0,-1)
var weapon_cue: Node3D
var palm_cues: Node3D
var stuck_time = 0.0
var magazine = 9
var reload_time = 0.0
var burst_left = 0
var burst_clock = 0.0
var settle_time = 0.0
var shots_fired = 0
var last_shot_origin = Vector3.ZERO
var last_shot_direction = Vector3.ZERO
var last_impact = Vector3.ZERO

func _ready():
	collision_layer = 2
	collision_mask = 1|2|4
	spawn_point = position
	seed = float(get_instance_id()%1000)*.13
	hp = [75.0,62.0,85.0,190.0][role] if kind == Kind.HOSTILE else 45.0
	floor_snap_length = .35
	floor_constant_speed = true
	safe_margin = .025
	var c = CollisionShape3D.new()
	var s = CapsuleShape3D.new()
	s.radius = .38
	s.height = 2.56 if role==3 else (2.44 if role==2 else 2.08)
	c.shape = s
	c.position.y = s.height*.5
	add_child(c)
	visual = SoldierRig.new()
	add_child(visual)
	visual.setup()
	visual.scale = [Vector3(1.10,1.14,1.10),Vector3(1.04,1.14,1.04),Vector3(.94,1.33,.98),Vector3(1.35,1.40,1.32)][role]
	visual.rifle.visible = has_firearm()
	magazine = magazine_size()
	shadow_mat = visual.material
	tell_light = OmniLight3D.new()
	tell_light.position.y = 1.9
	tell_light.omni_range = 3
	tell_light.light_color = Color(1,.035,.08)
	tell_light.light_cull_mask = 1
	tell_light.light_energy = 0
	add_child(tell_light)

func cue_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color):
	var m = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	m.mesh = shape
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)

func sees_player() -> bool:
	if not is_instance_valid(player):
		return false
	var from = global_position+Vector3(0,1.8,0)
	var to = target_point()
	if from.distance_to(to)>(26 if player.light_on and player.battery>0 else 18):
		return false
	var horizontal = Vector3(to.x-from.x,0,to.z-from.z)
	if horizontal.length()>3 and horizontal.normalized().dot(facing)<(-.2 if player.light_on else .15):
		return false
	var q = PhysicsRayQueryParameters3D.create(from,to,1|4)
	q.exclude = [get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider == player

func observe(dt):
	if not alive:
		return
	if revealed: return
	observed += dt
	if observed >= 1.0:
		revealed = true
		if kind != Kind.HOSTILE:
			GameState.say("MILO", "No weapon. They're looking for the door.",{"priority":0,"ttl":4,"key":"unarmed"})
		else:
			GameState.toast(["LURKER / RIFLE RAISED", "RUSHER / LISTEN FOR THE INHALE", "STALKER / KEEP IT IN VIEW", "APEX / BREAK SIGHT BEFORE THE PULSE"][role])

func description() -> String:
	if surrendered:
		return "HANDS RAISED  /  LET THEM PASS"
	if not revealed:
		return "UNKNOWN  /  HOLD THE LIGHT ON THEM"
	if kind == Kind.AFRAID:
		return "EMPTY HANDS  /  FRIGHTENED"
	if kind == Kind.FLEEING:
		return "FLEEING  /  NOT AIMING AT YOU"
	return ["LURKER / WATCH THE RIFLE", "RUSHER / CLOSE-RANGE BURSTS", "STALKER / WATCH THE MUZZLE", "APEX / RIFLE AND PULSE"][role]

func has_firearm() -> bool: return kind==Kind.HOSTILE and not surrendered
func magazine_size() -> int: return [9,8,6,12][role]
func target_point() -> Vector3: return player.global_position+Vector3.UP*(.7 if player.crouched else 1.2)

func hear_shot(pos: Vector3):
	if not alive or surrendered:
		return
	if global_position.distance_to(pos) < 23:
		last_heard = pos
		var sound_dir = pos-global_position
		sound_dir.y = 0
		if sound_dir.length()>.1:
			facing = sound_dir.normalized()
		has_heard = true
		last_fire = time_alive
		trust = 0
		if kind == Kind.HOSTILE and state == State.IDLE:
			state = State.SEARCH
		elif kind != Kind.HOSTILE:
			state = State.FLEE

func _physics_process(dt):
	time_alive += dt
	if not is_instance_valid(player):
		return
	if not alive:
		dead_time += dt
		update_visual(dt,Vector3.ZERO)
		# A persistent collapsed body is evidence in the memory, never a vanishing card.
		if dead_time>2: set_physics_process(false)
		return
	if game.cinematic_active or game.transitioning:
		update_visual(dt,Vector3.ZERO)
		return
	can_see = sees_player()
	is_watched = player.looking_at(global_position+Vector3(0,1.7,0),.82)
	under_light = player.light_on and player.battery>0 and player.lamp.visible and player.looking_at(global_position+Vector3(0,1.7,0),.95) and global_position.distance_to(player.global_position)<19
	lit_time = lit_time+dt if under_light else maxf(0,lit_time-dt*2)
	if under_light: observe(dt*.6)
	shadow_mat.set_shader_parameter("illumination",minf(1,lit_time*1.5))
	hurt_reaction = maxf(0,hurt_reaction-dt*3)
	shadow_mat.set_shader_parameter("hurt",hurt_reaction)
	whisper_timer -= dt
	if whisper_timer<=0 and global_position.distance_to(player.global_position)<20:
		whisper_timer = 6+fmod(seed,4)
		Sound.at(["lurker","rusher","stalker","apex"][role],global_position,.28 if role!=3 else .5)
	var dist = global_position.distance_to(player.global_position)
	cooldown = maxf(0,cooldown-dt)
	suppressed = maxf(0,suppressed-dt)
	if can_see:
		last_heard = player.global_position
		var sight_dir = player.global_position-global_position
		sight_dir.y = 0
		if sight_dir.length()>.1:
			facing = sight_dir.normalized()
		has_heard = true
	# Peace needs distance, attention, a pause in fire, and an opponent willing to listen.
	var willing = kind != Kind.HOSTILE or (identity.begins_with("guard") and revealed)
	if willing and can_see and GameState.lowered and revealed and dist>2.5 and dist<13 and time_alive-last_fire>4 and state != State.WINDUP:
		trust += dt
		if trust >= (2.6 if kind == Kind.HOSTILE else 1.8) and not surrendered:
			surrendered = true
			state = State.SURRENDER
			GameState.note_witness(identity)
			GameState.say("MILO","They're letting us through. Keep your hands where they can see them.",{"priority":0,"ttl":5,"key":"mercy"})
	else:
		trust = maxf(0,trust-dt*1.2)
	if surrendered:
		velocity.x = move_toward(velocity.x,0,dt*12)
		velocity.z = move_toward(velocity.z,0,dt*12)
		tell_light.light_energy = 0
		shadow_mat.set_shader_parameter("agitation",0)
	elif kind != Kind.HOSTILE:
		if trust > 0 or (GameState.lowered and can_see):
			velocity.x = move_toward(velocity.x,0,dt*9)
			velocity.z = move_toward(velocity.z,0,dt*9)
		elif can_see or state == State.FLEE:
			state = State.FLEE
			var safe = spawn_point+Vector3(3 if spawn_point.x<0 else -3,0,6)
			go_to(safe,2.4,dt)
	else:
		combat(dt,dist)
	velocity.y -= 19.5*dt
	if is_on_floor():
		velocity.y = -.2
	var before = global_position
	var requested = Vector2(velocity.x,velocity.z).length()
	move_and_slide()
	var actual = (global_position-before)/maxf(.0001,dt)
	stuck_time = stuck_time+dt if requested>.7 and Vector2(actual.x,actual.z).length()<.15 else 0.0
	if stuck_time>.55:
		path_timer = 0
		stuck_time = 0
	update_visual(dt,actual)

func update_visual(dt: float, actual: Vector3):
	if alive and facing.length()>.1:
		var target = atan2(facing.x,facing.z)
		visual.rotation.y += clampf(angle_difference(visual.rotation.y,target),-dt*5.5,dt*5.5)
	var aim = aim_point if state in [State.WINDUP,State.BURST] else (target_point() if can_see and has_firearm() else Vector3.INF)
	visual.update_pose(dt,actual,role,state,hurt_reaction,not alive,has_firearm(),aim)

func combat(dt, dist):
	if state==State.RELOAD:
		reload_time -= dt
		velocity.x = move_toward(velocity.x,0,dt*15)
		velocity.z = move_toward(velocity.z,0,dt*15)
		if reload_time<=0:
			magazine = magazine_size()
			state = State.RECOVER
			cooldown = .5
		return
	if state==State.BURST:
		advance_burst(dt)
		return
	if role==3:
		pulse_timer -= dt
		if pulse_windup>0:
			pulse_windup -= dt
			tell_light.light_energy = (1.5-pulse_windup)*2.2
			shadow_mat.set_shader_parameter("agitation",1-pulse_windup/1.5)
			velocity.x = 0
			velocity.z = 0
			if pulse_windup<=0:
				if sees_player() and dist<16:
					player.battery = maxf(0,player.battery-16)
					player.light_disruption = 2.5
					GameState.toast("THE LIGHT FALTERS / BREAK LINE OF SIGHT")
				Sound.at("pulse",global_position,.75)
				tell_light.light_energy = 0
				shadow_mat.set_shader_parameter("agitation",0)
				pulse_timer = 10
			return
		if pulse_timer<=0 and can_see and dist<16:
			pulse_windup = 1.5
			GameState.toast("APEX PULSE / GET BEHIND COVER")
			Sound.at("apex",global_position,.65)
			return
	if role==0 and lit_time>1.4 and state!=State.WINDUP:
		suppressed = maxf(suppressed,.1)
		if lit_time>2.2: lit_time = 0
	if suppressed > 0:
		velocity.x *= .75
		velocity.z *= .75
		return
	if magazine<=0:
		state = State.RELOAD
		reload_time = float(SoldierRig.clips["reload"].length)+.1
		Sound.at("reload",global_position,.38)
		return
	if state == State.WINDUP:
		windup -= dt
		velocity.x = move_toward(velocity.x,0,dt*15)
		velocity.z = move_toward(velocity.z,0,dt*15)
		if windup>.30:
			aim_point = target_point()+Vector3(player.velocity.x,0,player.velocity.z)*.07
		var intensity = clampf(1.0-windup/.9,0,1)
		shadow_mat.set_shader_parameter("agitation",intensity)
		tell_light.light_energy = intensity*1.8
		if windup<=0:
			state = State.BURST
			burst_left = mini([3,2,2,3][role],magazine)
			burst_clock = 0
			advance_burst(0)
			shadow_mat.set_shader_parameter("agitation",0)
			tell_light.light_energy = 0
		return
	if can_see and cooldown<=0 and dist<[19.0,13.0,17.0,20.0][role] and trust<=0:
		state = State.WINDUP
		windup = [.95,.65,.8,1.15][role]
		aim_point = target_point()
		Sound.at(["lurker","rusher","stalker","apex"][role],global_position,.6)
		return
	if role==2 and is_watched and dist>2.9:
		velocity.x = move_toward(velocity.x,0,dt*18)
		velocity.z = move_toward(velocity.z,0,dt*18)
		return
	if settle_time>0:
		settle_time = maxf(0,settle_time-dt)
		velocity.x = move_toward(velocity.x,0,dt*14)
		velocity.z = move_toward(velocity.z,0,dt*14)
		return
	if trust>0:
		velocity.x *= .7
		velocity.z *= .7
		return
	if can_see:
		state = State.ADVANCE if dist>9 else State.STRAFE
		var target = player.global_position
		if role == 0:
			var side = -1.0 if sin(seed)>0 else 1.0
			if dist<8:
				target = global_position+(global_position-player.global_position).normalized()*2+Vector3(side*3,0,0)
		elif role == 1 and dist>5:
			var side = -1.0 if sin(seed)>0 else 1.0
			var approach = (player.global_position-global_position).normalized()
			target += Vector3(-approach.z,0,approach.x)*side*1.5
		if role==2:
			target = player.global_position+player.global_basis.z*2.4
		go_to(target,[1.6,4.8,4.0,2.3][role]*(1.2 if role==1 and under_light else 1.0),dt)
	elif has_heard and global_position.distance_to(last_heard)>1.3:
		state = State.SEARCH
		go_to(last_heard,[1.5,3.2,3.8,1.8][role],dt)
	else:
		state = State.IDLE
		velocity.x = move_toward(velocity.x,0,dt*8)
		velocity.z = move_toward(velocity.z,0,dt*8)

func go_to(target: Vector3, speed: float, dt: float):
	path_timer -= dt
	# Keep an active stair route intact. Replanning halfway up can send an agent back down.
	var on_stairs = absf(global_position.x)<2 and global_position.z>11.5 and global_position.z<22
	var arrived = Vector2(target.x-global_position.x,target.z-global_position.z).length()<.5 and absf(target.y-global_position.y)<.6
	if arrived:
		velocity.x = move_toward(velocity.x,0,dt*12)
		velocity.z = move_toward(velocity.z,0,dt*12)
		return
	if (not on_stairs and (path_timer<=0 or route_goal.distance_to(target)>1.5)) or path.is_empty():
		path_timer = .8+fmod(seed,.2)
		route_goal = target
		path = building.route(global_position,target)
		if path.size()>1: path.remove_at(0)
	# Skip grid corners only when the full body can travel the shortcut safely.
	if not on_stairs and path.size()>1:
		for i in range(mini(path.size()-1,5),0,-1):
			var point = path[i]
			var safe_wing = point.x*global_position.x>0 and absf(point.x)>2.5 and absf(global_position.x)>2.5
			var safe_bridge = (point.z<11 and global_position.z<11) or (point.z>23 and global_position.z>23)
			if absf(point.y-global_position.y)>.4 or not (safe_wing or safe_bridge): continue
			var start = global_transform
			start.origin.y += .06
			var motion = Vector3(point.x-global_position.x,0,point.z-global_position.z)
			if not test_move(start,motion):
				for j in range(i): path.remove_at(0)
				break
	var dir = Vector3.ZERO
	while not path.is_empty():
		var next = path[0]
		var horizontal = Vector3(next.x-global_position.x,0,next.z-global_position.z)
		if horizontal.length()<.38 and absf(next.y-global_position.y)<.65:
			path.remove_at(0)
		else:
			dir = horizontal.normalized()
			break
	for door in building.doors:
		if door.centre().distance_to(global_position+Vector3(0,1.3,0))<1.5 and absf(door.angle())<.8:
			door.open_for_shadow(dt,self)
	for other in get_tree().get_nodes_in_group("shadows"):
		if other==self or not other.alive or absf(other.global_position.y-global_position.y)>1: continue
		var delta = global_position-other.global_position
		delta.y = 0
		if delta.length()<.9 and delta.length()>.01: dir += delta.normalized()*.6
	dir = dir.limit_length(1.0)
	if dir.length()>.1 and not can_see: facing = dir.normalized()
	velocity.x = move_toward(velocity.x,dir.x*speed,dt*10)
	velocity.z = move_toward(velocity.z,dir.z*speed,dt*10)

func hear_noise(pos: Vector3, distance: float):
	if not alive or surrendered or global_position.distance_to(pos)>distance: return
	last_heard = pos
	has_heard = true
	if kind==Kind.HOSTILE: state = State.SEARCH

func advance_burst(dt: float):
	velocity.x = move_toward(velocity.x,0,dt*18)
	velocity.z = move_toward(velocity.z,0,dt*18)
	if not has_firearm() or not sees_player():
		finish_burst()
		return
	burst_clock -= dt
	if burst_clock<=0 and burst_left>0:
		attack()
		burst_left -= 1
		burst_clock = [.16,.20,.23,.25][role]
	if burst_left<=0: finish_burst()

func finish_burst():
	burst_left = 0
	state = State.RECOVER
	cooldown = [1.6,1.2,1.8,2.1][role]
	settle_time = .32

func attack() -> bool:
	if not alive or not has_firearm() or magazine<=0: return false
	var from = visual.muzzle_position()
	var basis = visual.weapon_transform().basis.orthonormalized()
	var spread = [.016,.028,.014,.02][role]
	var direction = (basis.z+basis.x*randf_range(-spread,spread)+basis.y*randf_range(-spread,spread)).normalized()
	var end = from+direction*35
	# A barrel clipping a wall cannot shoot through it into the next room.
	var obstruction = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.5,from,1)
	var blocked = get_world_3d().direct_space_state.intersect_ray(obstruction)
	if not blocked.is_empty():
		from = blocked.position+blocked.normal*.015
		end = blocked.position
	var q = PhysicsRayQueryParameters3D.create(from,end,1|2|4)
	q.exclude = [get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		end = hit.position
		if hit.collider == player:
			player.hurt([6,6,7,8][role])
		elif hit.collider is ShadowSoldier:
			hit.collider.suppressed = maxf(hit.collider.suppressed,.25)
		game.impact(hit.position,hit.normal,hit.collider is ShadowSoldier)
	elif not blocked.is_empty(): game.impact(blocked.position,blocked.normal,false)
	magazine -= 1
	shots_fired += 1
	last_shot_origin = from
	last_shot_direction = direction
	last_impact = end
	visual.fire()
	game.tracer(from,end,Color(1,.24,.13))
	game.eject_shell(visual.muzzle_position()-basis.z*.55+basis.x*.07,basis)
	game.shot_smoke(visual.muzzle_position())
	Sound.at("rifle",visual.muzzle_position(),.65)
	return true

func take_hit(damage: float):
	if not alive:
		return
	hp -= damage
	hurt_reaction = 1.0
	velocity += (global_position-player.global_position).normalized()*2
	suppressed = .35
	has_heard = true
	last_heard = player.global_position
	last_fire = time_alive
	trust = 0
	if state in [State.WINDUP,State.BURST]:
		burst_left = 0
		state = State.RECOVER
		cooldown = .65
		tell_light.light_energy = 0
		shadow_mat.set_shader_parameter("agitation",0)
	if hp<=0:
		alive = false
		state = State.DEAD
		collision_layer = 0
		GameState.kills += 1
		if kind != Kind.HOSTILE or surrendered:
			GameState.casualties += 1
			GameState.say("MILO", "I didn't see a weapon.",{"priority":1,"ttl":8,"key":"unarmed_casualty"})
		Sound.at("land",global_position,.8)
		Sound.at("memory",global_position,.3)
		game.shadow_residue(global_position)
		tell_light.light_energy = 0
