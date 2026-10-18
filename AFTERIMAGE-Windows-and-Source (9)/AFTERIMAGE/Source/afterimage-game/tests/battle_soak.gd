extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate()
 root.add_child(g)
 root.get_node("GameState").new_run()
 g.start_chapter()
 var p=g.player
 p.invulnerable=9999
 p.pitch=-.055
 var e=get_nodes_in_group("shadows")[0]
 e.position=Vector3(-4,.04,10)
 e.hp=99999
 var base=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var maximum=base
 var axis=0.0
 for i in range(90):
  if i%10==0:
   p.ammo=9
   p.fire_time=0
   p.try_fire()
   e.attack()
  await process_frame
  maximum=maxf(maximum,Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
  var basis=e.visual.weapon_transform().basis
  axis=maxf(axis,maxf(basis.x.length(),maxf(basis.y.length(),basis.z.length())))
  if i in [30,85]:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("/workspace/scratch/0c86cfa275f7/qa/v8-battle-%d.png"%i)
 var ok=axis<1.5 and maximum<base+350 and e.shots_fired>3 and p.camera.global_position.is_finite()
 print("BATTLE RESULT ",ok," shots ",e.shots_fired," nodes_base_max ",base," ",maximum," max_weapon_axis ",axis)
 root.get_node("Sound").shutdown()
 g.queue_free()
 await process_frame
 await process_frame
 quit(0 if ok else 1)
