extends SceneTree
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok,message):
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",message)
func run():
 var g=load("res://scenes/main.tscn").instantiate()
 root.add_child(g)
 root.get_node("GameState").new_run()
 g.start_chapter()
 for e in get_nodes_in_group("shadows"):e.set_physics_process(false)
 var p=g.player
 root.disable_3d=true
 Engine.max_fps=240
 Engine.physics_ticks_per_second=20
 await process_frame
 var old=p.camera.global_basis
 var input=InputEventMouseMotion.new()
 input.screen_relative=Vector2(100,35)
 p._input(input)
 check(not p.camera.global_basis.is_equal_approx(old),"Mouse aim reaches the camera immediately, before a physics tick")
 check(absf(p.camera.global_basis.z.normalized().dot((Basis(Vector3.UP,p.yaw)*Basis(Vector3.RIGHT,p.head.rotation.x)).z))>.999,"Mouse aim preserves the requested yaw without rotational smoothing")
 p.yaw=PI
 p.pitch=0
 p.held[KEY_W]=true
 var vertical=InputEventMouseMotion.new()
 vertical.screen_relative=Vector2(0,20)
 var before_pitch=p.camera.global_basis.z.y
 p._input(vertical)
 check(absf(before_pitch-p.camera.global_basis.z.y)>.001,"Vertical mouse aim also updates before the next physics or render tick")
 var intervals=0
 var interpolated=0
 var last_body=p.position
 var last_camera=p.camera.global_position
 var largest=0.0
 for i in range(90):
  await process_frame
  var camera_pos=p.camera.global_position
  if p.position.is_equal_approx(last_body) and p.position.distance_squared_to(p.previous_position)>.00001:
   intervals+=1
   if camera_pos.distance_to(last_camera)>.00001:interpolated+=1
  largest=maxf(largest,camera_pos.distance_to(last_camera))
  last_body=p.position
  last_camera=camera_pos
 check(intervals>20 and interpolated>intervals*.75,"Camera translation continues between 20 Hz collision ticks at a 240 Hz render cap")
 p.release_inputs()
 p.position=Vector3(4.1,4.54,23.4)
 p.sync_camera()
 check(p.camera.global_position.distance_to(p.position+Vector3.UP*p.head.position.y)<.001,"Teleport resets camera location without sliding through the map")
 p.kick_pitch=.15
 p.kick_velocity=5
 p.update_view(.4,0,false)
 check(is_finite(p.kick_pitch) and p.kick_pitch>=0 and p.kick_pitch<=.16,"Recoil remains bounded after a 400 ms frame")
 g.pause_to("pause")
 var transform=p.camera.global_transform
 await create_timer(.08).timeout
 check(p.camera.global_transform.is_equal_approx(transform),"Pausing freezes the interpolated camera")
 g.resume()
 Engine.physics_ticks_per_second=60
 print("CAMERA RESULT ",checks-failures,"/",checks," intertick_frames ",interpolated,"/",intervals," max_step ",largest)
 root.get_node("Sound").shutdown()
 g.queue_free()
 await process_frame
 await process_frame
 quit(1 if failures else 0)
