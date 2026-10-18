extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(ok,message):
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",message)
func run():
 var g=load("res://scenes/main.tscn").instantiate()
 root.add_child(g)
 root.get_node("GameState").new_run()
 g.start_chapter()
 for actor in get_nodes_in_group("shadows"):actor.set_physics_process(false)
 var p=g.player
 p.set_physics_process(false)
 var e=get_nodes_in_group("shadows")[0]
 e.position=Vector3(-4,.04,9)
 e.visual.rotation.y=PI
 var maximum=0.0
 var distortion=0.0
 var finite=true
 var started=Time.get_ticks_usec()
 for i in range(36000):
  var state=10 if i%480>360 else (9 if i%480>180 else 4)
  var goal=Vector3(-4+sin(i*.018)*5,1.1+sin(i*.01)*.5,3)
  e.visual.update_pose(1.0/60,Vector3(sin(i*.04),0,0),i%4,state,0,false,true,goal)
  if i%12==0:e.visual.fire()
  var transform=e.visual.weapon_transform()
  var axes=Vector3(transform.basis.x.length(),transform.basis.y.length(),transform.basis.z.length())
  maximum=maxf(maximum,maxf(axes.x,maxf(axes.y,axes.z)))
  distortion=maxf(distortion,absf(axes.x-axes.y)+absf(axes.y-axes.z))
  finite=finite and transform.origin.is_finite() and axes.is_finite()
 check(finite and maximum<1.5 and distortion<.00001,"36,000 moving aim/fire/reload poses retain finite, uniformly scaled firearms")
 check((e.visual.rifle.global_transform*Vector3(0,.025,.77)).distance_to(e.visual.muzzle_position())<.001,"Rendered rifle muzzle and ballistic muzzle agree after ten simulated minutes")
 print("STRESS_MAX_AXIS ",maximum," distortion ",distortion," pose_ms ",float(Time.get_ticks_usec()-started)/36000000.0)
 for i in range(100):
  g.tracer(Vector3(-4,1,3),Vector3(-4,1,4),Color.WHITE)
  g.eject_shell(Vector3(-4,1,3),Basis.IDENTITY)
  g.shot_smoke(Vector3(-4,1,3))
  g.impact(Vector3(-4,1,4),Vector3.BACK,false)
  root.get_node("Sound").play("rifle",.1)
 await process_frame
 var bounded=true
 for category in g.effect_pools:
  var limit={"tracers":12,"casings":16,"muzzle_smoke":8,"impacts":12,"marks":40}[category]
  bounded=bounded and g.effect_pools[category].filter(func(n):return is_instance_valid(n) and not n.is_queued_for_deletion()).size()<=limit
 check(bounded,"100 simultaneous shots keep tracers, casings, smoke, impacts and decals within their budgets")
 check(root.get_node("Sound").voices.filter(func(n):return is_instance_valid(n)).size()<=24,"Combat sound voices stay within the 24 voice budget")
 await create_timer(3).timeout
 check(g.effect_pools["casings"].filter(func(n):return is_instance_valid(n)).is_empty(),"Ejected casing bodies expire after their short settled lifetime")
 root.get_node("Sound").shutdown()
 g.queue_free()
 await process_frame
 await process_frame
 print("STABILITY RESULT ",5-failures,"/5")
 quit(1 if failures else 0)
