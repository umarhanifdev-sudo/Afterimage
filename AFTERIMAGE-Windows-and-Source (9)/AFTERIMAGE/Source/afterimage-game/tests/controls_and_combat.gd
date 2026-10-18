extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func frames(n):
	for i in range(n):
		await physics_frame
		await process_frame
func check(ok,message):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",message)
func run():
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	var state=root.get_node("GameState")
	state.new_run()
	g.start_chapter()
	var p=g.player
	p.set_physics_process(false)
	for e in get_nodes_in_group("shadows"):e.set_physics_process(false)
	var armed=true
	var empty=true
	for e in get_nodes_in_group("shadows"):
		e.update_visual(.016,Vector3.ZERO)
		if e.kind==0:armed=armed and e.visual.rifle.visible
		else:empty=empty and not e.visual.rifle.visible
	check(armed,"Every hostile archetype has a firearm in the first memory")
	check(empty,"Frightened and peaceful people remain unarmed")
	p.locked=true
	g.pause_to("pause")
	g.on_ui("settings")
	g.on_ui("back")
	g.resume()
	check(not p.locked and p.camera.is_current() and not paused,"Resume restores camera ownership and clears stale locks")
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var click=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	g._input(click)
	check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not p.firing,"A recapture click restores look without firing")
	var motion=InputEventMouseMotion.new()
	motion.screen_relative=Vector2(40,12)
	var yaw=p.yaw
	var pitch=p.pitch
	p._input(motion)
	check(p.yaw<yaw and p.pitch<pitch,"Captured screen-relative motion changes camera aim")
	p.locked=true
	await frames(2)
	check(not p.locked,"An orphaned gameplay lock recovers on the next frame")
	g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused and g.hud.mode=="pause","Losing window focus pauses safely")
	g.resume()
	var panel=g.building.mounted_panels[0].node
	var bounds=panel.transform*panel.get_aabb()
	var ray=PhysicsRayQueryParameters3D.create(Vector3(bounds.end.x-.02,6,23.4),Vector3(6.3,6,23.4),1)
	ray.exclude=[panel.get_child(0).get_rid()]
	var hit=g.world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and absf(hit.position.x-bounds.end.x)<.005,"Circuit panel back meets the physical wall")
	var power=g.building.interactables.filter(func(item):return item.id=="power")[0]
	p.position=Vector3(4.1,4.54,23.4)
	await frames(2)
	var direction=(power.pos-p.camera.global_position).normalized()
	p.yaw=atan2(-direction.x,-direction.z)
	p.pitch=asin(direction.y)
	p.rotation.y=p.yaw
	p.head.rotation.x=p.pitch
	p.update_target(.016)
	check(p.interaction.get("id","")=="power","Mounted circuit remains reachable through the interaction system")
	var bed_ok=true
	for bed in g.building.bed_layouts:bed_ok=bed_ok and bed.anchor.z-1.2-bed.wall_z<.16
	check(g.building.bed_layouts.size()>6 and bed_ok,"Bedroom headboards sit against the rear wall")
	g.building.box(Vector3(35,-.15,10),Vector3(18,.3,20),Color.GRAY,true,false)
	var e=get_nodes_in_group("shadows")[0]
	e.position=Vector3(35,.04,12)
	p.position=Vector3(35,.04,4)
	e.facing=Vector3(0,0,-1)
	e.visual.rotation.y=PI
	e.kind=0
	e.can_see=true
	e.aim_point=e.target_point()
	await frames(3)
	for role in range(4):
		e.role=role
		e.magazine=9
		e.state=e.State.WINDUP
		state.health=100
		p.invulnerable=0
		for i in range(60):e.update_visual(1.0/60,Vector3.ZERO)
		var origin=e.visual.muzzle_position()
		var forward=e.visual.muzzle_direction()
		var fired=e.attack()
		check(fired and state.health<100,"Archetype %d fires a damaging shot at eight metres"%role)
		check(e.last_shot_origin.distance_to(origin)<.002 and e.last_shot_direction.dot(forward)>.995,"Archetype %d shot follows the animated barrel"%role)
	check(e.visual.flash_time>0 and e.visual.recoil_velocity>0,"A shot triggers muzzle flash and a recoil impulse")
	var wall=g.building.box(Vector3(35,1.5,8),Vector3(4,3,.3),Color.GRAY)
	await frames(3)
	state.health=100
	p.invulnerable=0
	e.attack()
	check(state.health==100 and absf(e.last_impact.z-8.15)<.05,"Solid cover blocks muzzle-origin gunfire")
	e.state=e.State.BURST
	e.burst_left=2
	e.advance_burst(.2)
	check(e.burst_left==0,"Breaking sight cancels the remaining burst")
	wall.queue_free()
	await frames(2)
	e.role=0
	e.state=e.State.BURST
	e.burst_left=3
	e.burst_clock=0
	e.magazine=9
	e.velocity=Vector3(2,0,0)
	var shots=e.shots_fired
	e.advance_burst(0)
	e.advance_burst(.05)
	check(e.shots_fired==shots+1,"A burst respects the delay between rounds")
	e.advance_burst(.12)
	e.advance_burst(.20)
	check(e.shots_fired==shots+3 and e.state==e.State.RECOVER and e.velocity.length()<.01,"Three-round burst braces, fires and enters recovery")
	p.crouched=true
	p.capsule.shape.height=1.1
	p.capsule.position.y=.55
	await frames(2)
	check(e.sees_player(),"Enemy sight targets the body of a crouching player")
	p.crouched=false
	p.capsule.shape.height=1.8
	p.capsule.position.y=.9
	e.role=0
	e.state=e.State.IDLE
	e.magazine=0
	e.suppressed=0
	e.combat(.016,8)
	e.update_visual(.016,Vector3.ZERO)
	check(e.state==e.State.RELOAD and e.visual.current=="reload","An empty magazine starts the supplied reload animation")
	e.combat(e.reload_time+.05,8)
	check(e.magazine==e.magazine_size(),"Reload refills the enemy magazine")
	e.kind=1
	var count=e.shots_fired
	check(not e.attack() and e.shots_fired==count,"An unarmed person cannot fire")
	print("CONTROLS AND COMBAT RESULT ",checks-failures,"/",checks)
	root.get_node("Sound").shutdown()
	await create_timer(.4).timeout
	quit(1 if failures else 0)
