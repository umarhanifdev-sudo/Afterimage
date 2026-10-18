extends SceneTree
func _initialize(): call_deferred("run")
func inspect_node(n):
	if n is MeshInstance3D:
		for i in range(n.mesh.get_surface_count()):
			var mat=n.mesh.surface_get_material(i)
			print(n.name," surface ",i," ",mat.resource_name," color ",mat.albedo_color," tex ",mat.albedo_texture)
	for c in n.get_children():inspect_node(c)
func run():
	for id in ['chair','table','sofa']:
		var n=load('res://assets/models/'+id+'/'+id+'.gltf').instantiate()
		inspect_node(n)
		n.free()
	var g=load('res://scenes/main.tscn').instantiate()
	root.add_child(g)
	root.get_node('GameState').new_run()
	g.start_chapter()
	for i in range(8): await physics_frame
	var p=g.player
	print('HAND ROOT ',p.hands.global_transform,' SKELETON ',p.hands.skeleton.transform)
	for side in ['R','L']:
		var bone=p.hands.skeleton.get_bone_global_pose(p.hands.bones['wrist_'+side]).origin
		print('WRIST ',side,' ',p.hands.skeleton.to_global(bone),' camera ',p.camera.to_local(p.hands.skeleton.to_global(bone)))
	inspect_node(p.hands.model)
	root.get_node('Sound').shutdown()
	await create_timer(.4).timeout
	quit()
