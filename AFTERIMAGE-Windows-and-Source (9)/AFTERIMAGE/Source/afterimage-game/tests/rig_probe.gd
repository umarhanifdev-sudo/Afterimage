extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var rig=load("res://scripts/human_rig.gd").new()
	root.add_child(rig)
	rig.setup("human",true)
	print("BONES ",rig.bones.keys())
	for i in range(5):
		rig.animate_shadow(.016,2.0,0,0,0,false,true)
	print("ANKLE ",rig.skeleton.get_bone_global_pose(rig.bones['foot_L']))
	quit()
