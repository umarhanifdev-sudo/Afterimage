extends SceneTree
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",message)
func frames(n):
	for i in range(n):
		await physics_frame
		await process_frame
func run():
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	root.get_node("GameState").new_run()
	g.start_chapter()
	var b=g.building
	for e in get_nodes_in_group("shadows"): e.set_physics_process(false)
	g.player.set_physics_process(false)
	var grounded=true
	var collided=true
	var count=0
	for prop in b.get_children():
		if not prop.has_meta("furniture_id"): continue
		count+=1
		var bounds=RoomProps.local_bounds(prop,prop)
		grounded=grounded and absf(prop.position.y+bounds.position.y*prop.scale.y-float(prop.get_meta("floor_y")))<.002
		collided=collided and is_instance_valid(prop.get_meta("collision_body"))
	check(count>40 and grounded,"Every imported furniture instance rests on its floor")
	check(collided,"Every imported chair, sofa and table has body collision")
	# Isolated physical samples avoid unrelated walls and room furnishings.
	b.box(Vector3(35,-.15,10),Vector3(16,.3,10),Color.GRAY,true,false)
	var table=RoomProps.imported(b,"table",Vector3(31,0,10),.45,Vector3(1,1.68,1.6))
	var chair=RoomProps.imported(b,"chair",Vector3(35,0,10),.7)
	RoomProps.bed(b,Vector3(39,0,10))
	await frames(3)
	var space=g.world.get_world_3d().direct_space_state
	var ray=PhysicsRayQueryParameters3D.create(Vector3(31,2,10),Vector3(31,.1,10),1)
	var hit=space.intersect_ray(ray)
	check(not hit.is_empty() and absf(hit.position.y-float(table.get_meta("surface_y")))<.01,"Rotated table collision matches its visible top")
	ray=PhysicsRayQueryParameters3D.create(Vector3(31,.30,9.8),Vector3(31,.30,10.2),1)
	check(space.intersect_ray(ray).is_empty(),"The clear space beneath a tabletop remains open to rays")
	var p=g.player
	for sample in [[Vector3(31,0,10),"table"],[Vector3(35,0,10),"chair"],[Vector3(39,0,10),"bed"]]:
		p.position=sample[0]+Vector3(-1.7,.04,0)
		p.velocity=Vector3.ZERO
		for i in range(85):
			await physics_frame
			p.velocity=Vector3(2.5,-.2,0)
			p.move_and_slide()
		check(p.position.x<float(sample[0].x)-.25,"Player cannot walk through a "+sample[1])
	var e=get_nodes_in_group("shadows")[0]
	e.position=Vector3(35,.04,8)
	var before=e.position
	e.visual.rotation.y=0
	for i in range(40): e.visual.update_pose(1.0/60,Vector3(0,0,1.6),0,1,0,false,false)
	check(e.visual.current=="walk" and e.position.is_equal_approx(before),"Walk clip animates limbs without moving the collision body")
	for i in range(30): e.visual.update_pose(1.0/60,Vector3(0,0,4.2),1,2,0,false,false)
	check(e.visual.current=="run","Fast forward movement selects the supplied run clip")
	for i in range(25): e.visual.update_pose(1.0/60,Vector3(1.6,0,0),0,3,0,false,true)
	check(e.visual.current=="left","Sideways movement selects a directional walk")
	for i in range(40): e.visual.update_pose(1.0/60,Vector3.ZERO,0,1,0,false,false)
	check(e.visual.current=="idle","A blocked or stopped enemy returns to idle")
	e.visual.fire()
	e.visual.update_pose(.05,Vector3.ZERO,0,4,0,false,true)
	check(e.visual.rifle.visible and e.visual.shot_time>0,"Rifle fire uses the supplied aim/shoot pose and attached weapon")
	e.visual.update_pose(.05,Vector3.ZERO,0,5,1,false,false)
	check(e.visual.hit_time>0,"Damage starts an authored upper-body hit reaction")
	for i in range(100): e.visual.update_pose(1.0/60,Vector3.ZERO,0,9,0,true,false)
	var head=e.visual.skeleton.get_bone_global_pose(e.visual.bones["B-head"]).origin
	check(head.y<.7 and e.visual.death_time>1.5,"Death ends in a persistent grounded collapse")
	print("PROPS AND MOTION RESULT ",checks-failures,"/",checks)
	root.get_node("Sound").shutdown()
	await create_timer(.4).timeout
	quit(1 if failures else 0)
