extends SceneTree
func _initialize():call_deferred("run")
func run():
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	root.get_node("GameState").new_run()
	g.start_chapter()
	g.player.invulnerable=9999
	for e in get_nodes_in_group("shadows"):e.set_physics_process(false)
	var samples=[]
	for i in range(125):
		await process_frame
		if i>=45:samples.append(Vector3(Performance.get_monitor(Performance.TIME_PROCESS)*1000,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	var total=Vector3.ZERO
	for s in samples:total+=s
	print("PROFILE ",OS.get_environment("PROFILE_LABEL")," mean_process_ms_drawcalls_triangles ",total/samples.size()," nodes ",Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	root.get_node("Sound").shutdown()
	await create_timer(.4).timeout
	quit()
