extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.on_ui("quit")
	if not g.quitting:
		print("FAIL Exit to Desktop action")
		quit(1)
	else: print("PASS Exit to Desktop starts the shared clean shutdown")
