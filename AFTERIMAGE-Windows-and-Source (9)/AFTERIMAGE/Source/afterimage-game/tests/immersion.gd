extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func frames(n):
	for i in range(n):
		await physics_frame
		await process_frame
func check(value,message):
	checks+=1
	if value: print("PASS ",message)
	else:
		failures+=1
		print("FAIL ",message)
func run():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var state=root.get_node("GameState")
	state.new_run()
	game.start_chapter(true)
	check(game.cinematic_active and game.player.locked,"Opening owns camera and locks combat")
	check(game.hud.letterbox==1,"Opening is letterboxed")
	game.pause_to("pause")
	var t=game.cinematic_time
	await frames(3)
	check(is_equal_approx(t,game.cinematic_time),"Pause freezes cinematic clock")
	game.resume()
	game.finish_intro()
	var p=game.player
	check(not p.locked and not game.cinematic_active and p.held.is_empty(),"Skip restores control and clears stale inputs")
	for e in get_nodes_in_group("shadows"): e.set_physics_process(false)
	p.held[KEY_W]=true
	await frames(20)
	var before=p.position.z
	p.hurt(12)
	check(not p.locked and p.hit_flinch>0,"Nonfatal hit adds flinch without locking controls")
	await frames(20)
	check(p.position.z>before+.7,"Player keeps moving after a hit")
	p.release_inputs()
	await frames(16)
	check(Vector2(p.velocity.x,p.velocity.z).length()<.1,"Movement brakes to rest")
	p.position=Vector3(-4,.08,3)
	p.held[KEY_CTRL]=true
	await frames(6)
	var ceiling=game.building.box(Vector3(-4,1.62,3),Vector3(1.5,.2,1.5),Color.GRAY)
	await frames(3)
	p.release_inputs()
	await frames(6)
	check(p.crouched,"Full upper-body overlap prevents standing into ceiling")
	ceiling.queue_free()
	await frames(8)
	check(not p.crouched,"Crouch recovers when obstruction clears")
	check(p.hands.skeleton.get_bone_count()==50 and p.body_model.skeleton.get_bone_count()==50,"First-person arms and body have skinning rigs")
	var e=get_nodes_in_group("shadows")[0]
	check(e.visual.skeleton.get_bone_count()>=50 and e.visual.animator.has_animation("walk"),"Shadow uses the supplied soldier rig and walk clip")
	var initial=e.visual.skeleton.get_bone_global_pose(e.visual.bones['B-hand.L']).origin
	for i in range(24): e.visual.update_pose(.016,Vector3(0,0,2),0,1,0,false,false)
	var later=e.visual.skeleton.get_bone_global_pose(e.visual.bones['B-hand.L']).origin
	check(initial.distance_to(later)>.02,"Locomotion changes weighted arm pose")
	e.take_hit(999)
	for i in range(90): e.visual.update_pose(.016,Vector3.ZERO,0,9,0,true,true)
	var head=e.visual.skeleton.get_bone_global_pose(e.visual.bones['B-head']).origin
	check(is_instance_valid(e) and not e.alive and head.y<.7,"Death clip collapses and preserves the 3D body")
	check(game.building.get_child_count()>200,"Furnished building initializes")
	print("IMMERSION RESULT ",checks-failures,"/",checks)
	root.get_node("Sound").shutdown()
	await create_timer(.4).timeout
	quit(1 if failures else 0)
