extends SceneTree
var g
func _initialize():call_deferred("run")
func shot(name):
 for i in range(4):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/workspace/scratch/0c86cfa275f7/qa/"+name+".png")
 print("CAPTURE ",name)
func run():
 g=load("res://scenes/main.tscn").instantiate()
 root.add_child(g)
 root.get_node("GameState").new_run()
 for chapter in [0,1]:
  root.get_node("GameState").chapter=chapter
  g.start_chapter()
  for e in get_nodes_in_group("shadows"):e.set_physics_process(false)
  g.player.set_physics_process(false)
  for i in range(50):g.player.update_view(1.0/60,0,false)
  await shot("v8-gameplay-%d"%chapter)
  g.player.ads=true
  for i in range(50):g.player.update_view(1.0/60,0,false)
  await shot("v8-ads-%d"%chapter)
  g.player.try_fire()
  g.player.update_view(.016,0,false)
  await shot("v8-fire-%d"%chapter)
 root.get_node("Sound").shutdown()
 g.queue_free()
 await process_frame
 await process_frame
 quit()
