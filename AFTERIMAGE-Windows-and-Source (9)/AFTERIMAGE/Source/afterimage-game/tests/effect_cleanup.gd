extends SceneTree
func _initialize():call_deferred("run")
func run():
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	var state=root.get_node("GameState")
	state.new_run()
	g.start_chapter()
	for e in get_nodes_in_group("shadows"):e.set_physics_process(false)
	await process_frame
	g.player.try_fire()
	g.impact(Vector3(-4,1.5,5),Vector3(0,0,-1),false)
	state.chapter=1
	g.start_chapter()
	await create_timer(1.1).timeout
	root.get_node("Sound").shutdown()
	await create_timer(.5).timeout
	g.queue_free()
	await process_frame
	await process_frame
	print("PASS Shot effects safely cancel when the world changes")
	quit()
