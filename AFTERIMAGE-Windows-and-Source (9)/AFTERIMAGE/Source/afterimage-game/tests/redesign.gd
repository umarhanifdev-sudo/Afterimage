extends SceneTree
var game
var state
var checks = 0
var failures = 0
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	checks += 1
	if value: print("PASS ",message)
	else:
		failures += 1
		print("FAIL ",message)
func frames(n: int):
	for i in range(n):
		await physics_frame
		await process_frame
func freeze():
	for e in get_nodes_in_group("shadows"): e.set_physics_process(false)
func aim(p, pos):
	var d = (pos-p.camera.global_position).normalized()
	p.yaw = atan2(-d.x,-d.z)
	p.pitch = asin(d.y)
	p.rotation.y = p.yaw
	p.head.rotation.x = p.pitch
func walk_to(p, target, max_frames=350):
	p.held[KEY_W] = true
	var count = 0
	while Vector2(p.position.x-target.x,p.position.z-target.z).length()>.25 and count<max_frames:
		var dir = target-p.position
		p.yaw = atan2(-dir.x,-dir.z)
		p.rotation.y = p.yaw
		await frames(1)
		count += 1
	p.release_inputs()
	p.velocity = Vector3.ZERO
	return count<max_frames
func item(id): return game.building.interactables.filter(func(i): return i.id==id)[0]
func run():
	state = root.get_node("GameState")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	state.new_run()
	game.start_chapter()
	freeze()
	await frames(8)
	var p=game.player
	p.invulnerable=1000
	check(game.building.grids.size()==4 and get_nodes_in_group("shadows").size()==7,"Four floors and seven encounters initialize")
	check(await walk_to(p,Vector3(-4,0,7)),"Player walks down entry corridor")
	p.held[KEY_W]=true
	p.held[KEY_SHIFT]=true
	await frames(20)
	check(Vector2(p.velocity.x,p.velocity.z).length()>6,"Sprint accelerates to grounded speed")
	p.start_slide()
	check(p.slide_time>0 and p.stamina<100,"Sliding consumes stamina")
	p.release_inputs()
	p.slide_time=0
	await frames(10)
	p.jump_buffer=.14
	await frames(9)
	check(p.position.y>.3,"Jump leaves ground")
	await frames(65)
	check(p.is_on_floor(),"Gravity returns player")
	p.position=Vector3(-1.06,.08,11.1)
	p.velocity=Vector3.ZERO
	for f in range(3):
		check(await walk_to(p,Vector3(-1.06,f*4.5+2.25,20.85)),"Stair ascending flight %d"%f)
		check(await walk_to(p,Vector3(1.06,f*4.5+2.25,20.85)),"Stair landing crossing %d"%f)
		check(await walk_to(p,Vector3(1.06,(f+1)*4.5,11.15)),"Stair return flight %d"%f)
		check(absf(p.position.y-(f+1)*4.5)<.2,"Reached floor %d physically"%(f+2))
		await walk_to(p,Vector3(-1.06,(f+1)*4.5,11.15))
	var d=game.building.doors.filter(func(door): return door.identity=="room_0_1_6")[0]
	p.position=Vector3(4.5,.08,6)
	p.velocity=Vector3.ZERO
	await frames(5)
	check(absf(d.angle())<.12,"Closed hinge holds door in frame")
	d.interact(p)
	await frames(110)
	print("DOOR angle ",d.angle()," target ",d.target_angle," centre ",d.centre())
	check(absf(d.angle())>1.1,"Door rotates open on its hinge")
	check(await walk_to(p,Vector3(8.5,0,6)),"Player can traverse opened doorway")
	d.interact(p)
	await frames(150)
	check(absf(d.angle())<.12,"Door closes against frame")
	var jam=game.building.doors.filter(func(door): return door.jammed)[0]
	jam.force(.8)
	check(jam.jammed,"Jammed door requires sustained effort")
	jam.force(.85)
	await frames(110)
	check(not jam.jammed and absf(jam.angle())>1.1,"Holding force releases jam and swings hinge")
	check(game.building.exit_door.locked,"Exit begins locked")
	game.interact(item("power"))
	check(state.power_on and not game.building.exit_door.locked,"Circuit unlocks physical exit")
	p.position=Vector3(-4,.08,3)
	p.velocity=Vector3.ZERO
	p.battery=50
	p.light_on=true
	var battery=p.battery
	await frames(60)
	check(p.battery<battery-.3,"Flashlight drains while on")
	p.light_on=false
	battery=p.battery
	await frames(40)
	check(is_equal_approx(p.battery,battery),"Flashlight off conserves battery")
	p.battery=0
	p.light_on=true
	p.update_light(.016)
	check(p.lamp.visible and p.lamp.spot_range==5,"Exhausted battery leaves a limited reserve beam")
	game.interact(item("battery_0"))
	check(p.battery==40 and item("battery_0").used,"Cell pickup restores charge once")
	p.interaction=item("charger_0")
	p.held[KEY_E]=true
	p.update_light(1)
	check(p.battery>60,"Holding generator interaction recharges light")
	p.release_inputs()
	var e=get_nodes_in_group("shadows")[0]
	e.position=Vector3(-4,.04,10)
	p.position=Vector3(-4,.08,3)
	await frames(3)
	aim(p,e.position+Vector3(0,1.5,0))
	p.fire_time=0
	var ammo=p.ammo
	p.try_fire()
	check(p.ammo==ammo-1 and e.hp<75,"Aimed shot consumes one round and damages shadow")
	var base_pitch=p.pitch
	await frames(5)
	check(p.kick_pitch>.005,"Shot visibly raises recoil spring")
	await frames(65)
	check(p.kick_pitch<.001 and is_equal_approx(p.pitch,base_pitch),"Recoil settles without modifying mouse baseline")
	var wall=game.building.box(Vector3(-4,1.5,6),Vector3(2,3,.3),Color.GRAY)
	await frames(3)
	var hp=e.hp
	p.fire_time=0
	p.try_fire()
	check(e.hp==hp and not e.sees_player(),"Walls block bullets and enemy sight")
	wall.queue_free()
	await frames(3)
	p.ammo=0
	p.start_reload()
	await frames(90)
	check(p.ammo==int(p.weapon.mag) and p.reserve<int(p.weapon.reserve),"Reload transfers reserve rounds")
	var route=game.building.route(Vector3(-4,0,3),Vector3(4,13.5,30))
	check(route.size()>25 and route[-1].y==13.5,"Enemy route includes stairs across all floors")
	var stalker=get_nodes_in_group("shadows")[4]
	stalker.position=Vector3(-4,.04,12)
	stalker.cooldown=9
	stalker.state=0
	stalker.is_watched=true
	stalker.velocity=Vector3.ZERO
	stalker.combat(.1,9)
	check(stalker.velocity.length()<.01,"Observed stalker stops advancing")
	stalker.is_watched=false
	stalker.can_see=true
	stalker.combat(.1,9)
	check(Vector2(stalker.velocity.x,stalker.velocity.z).length()>.1,"Unobserved stalker advances")
	var apex=get_nodes_in_group("shadows")[5]
	apex.position=Vector3(-4,.04,11)
	apex.facing=Vector3(0,0,-1)
	apex.can_see=true
	apex.pulse_timer=0
	apex.combat(.016,8)
	check(apex.pulse_windup>1,"Apex pulse has a visible warning")
	battery=p.battery
	apex.combat(1.6,8)
	check(p.battery<battery and p.light_disruption>0,"Exposed player loses battery to pulse")
	wall=game.building.box(Vector3(-4,1.5,6),Vector3(2,3,.3),Color.GRAY)
	await frames(3)
	battery=p.battery
	apex.pulse_windup=.1
	apex.combat(.2,8)
	check(p.battery==battery,"Cover blocks the apex pulse")
	wall.queue_free()
	state.chapter=1
	e.kind=1
	e.revealed=true
	check(not game.milo.permits(e),"Milo refuses a revealed unarmed target")
	e.kind=0
	check(game.milo.permits(e),"Milo permits defense against a threat")
	e.surrendered=true
	check(not game.milo.permits(e),"Milo protects surrendered people")
	state.chapter=3
	check(not game.milo.permits(null),"Remembrance ends fire orders")
	state.begin_chapter()
	game.start_chapter()
	freeze()
	p=game.player
	p.set_physics_process(false)
	await frames(5)
	for id in ["photo","manifest","wristband"]:
		var clue=item(id)
		p.position=Vector3(clue.pos.x,game.building.floor_index(clue.pos)*4.5+.04,clue.pos.z-2)
		if id=="wristband": p.position.z = clue.pos.z+1.8
		await frames(3)
		aim(p,clue.pos)
		p.update_target(.016)
		check(p.interaction.get("id","")==id,"Clue can be focused and interacted with: "+id)
		game.interact(clue)
	check(state.clues.size()==3,"Three fragments recovered")
	game.interact(item("exit"))
	check(game.hud.mode=="choice","Final door opens narrative choice")
	game.on_ui("accept")
	await frames(4)
	check(game.hud.mode=="ending" and game.hud.ending=="acceptance","Acceptance ending appears")
	game.on_ui("reconsider")
	game.on_ui("insist")
	await frames(4)
	check(game.hud.ending=="rationalization","Alternate ending remains reconsiderable")
	paused=false
	root.get_node("Sound").shutdown()
	await create_timer(.5).timeout
	print("RESULT ",checks-failures,"/",checks," passed")
	game.queue_free()
	await frames(5)
	quit(1 if failures else 0)
