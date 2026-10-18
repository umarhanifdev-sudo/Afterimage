extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	root.get_node("GameState").new_run()
	g.start_chapter()
	for e in get_nodes_in_group("shadows"): e.set_physics_process(false)
	var e=get_nodes_in_group("shadows")[0]
	e.position=Vector3(-4,.04,10)
	g.player.position=Vector3(4,13.54,31)
	g.player.locked=true
	var target=Vector3(4,13.5,30)
	var reached=false
	for i in range(2700):
		await physics_frame
		e.go_to(target,3.5,1.0/60)
		e.velocity.y-=19.5/60
		if e.is_on_floor(): e.velocity.y=-.2
		e.move_and_slide()
		if i%300==0: print("NAV ",i," ",e.position," next ",e.path[0] if not e.path.is_empty() else Vector3.ZERO)
		if e.position.distance_to(target)<1:
			reached=true
			break
	print("NAV_RESULT ",reached)
	root.get_node("Sound").shutdown()
	await create_timer(.5).timeout
	g.queue_free()
	await process_frame
	quit(0 if reached else 1)
