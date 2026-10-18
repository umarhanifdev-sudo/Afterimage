extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(ok,message):
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",message)
func frames(n):
 for i in range(n):await physics_frame
func run():
 var world=Node3D.new()
 root.add_child(world)
 var floor_body=StaticBody3D.new()
 var floor_col=CollisionShape3D.new()
 var floor_shape=BoxShape3D.new()
 floor_shape.size=Vector3(10,.2,10)
 floor_col.shape=floor_shape
 floor_body.position.y=-.1
 floor_body.add_child(floor_col)
 world.add_child(floor_body)
 var d=load("res://scripts/door.gd").new()
 d.wood=StandardMaterial3D.new()
 world.add_child(d)
 var actor=Node3D.new()
 world.add_child(actor)
 actor.position=Vector3(.9,0,-1)
 d.interact(actor)
 await frames(100)
 check(d.angle()< -1.6,"Door opens away without hitting the floor")
 var stable=true
 for cycle in range(6):
  d.target_angle=0
  await frames(90)
  stable=stable and absf(d.angle())<.001 and d.leaf.position.distance_to(Vector3(.9,1.375,0))<.001
  d.target_angle=1.67 if cycle%2 else -1.67
  await frames(90)
 check(stable,"Repeated swings retain exact hinge/closed position")
 var block=CharacterBody3D.new()
 block.collision_layer=4
 var col=CollisionShape3D.new()
 var shape=BoxShape3D.new()
 shape.size=Vector3(.4,2,.4)
 col.shape=shape
 block.add_child(col)
 world.add_child(block)
 block.position=Vector3(.9,1,.05)
 await frames(2)
 d.target_angle=0
 await frames(100)
 var stopped=d.angle()
 await frames(100)
 check(absf(stopped)>.15 and absf(d.angle()-stopped)<.00001,"Actor blocks closing without shaking or shoving")
 block.queue_free()
 await frames(100)
 check(absf(d.angle())<.001,"Door resumes closing after obstruction leaves")
 d.locked=true
 d.target_angle=1.7
 await frames(100)
 check(absf(d.angle())<.001,"Lock holds door closed")
 d.locked=false
 d.jammed=true
 d.force(.8,actor)
 check(d.jammed,"Jam requires sustained force")
 d.force(.81,actor)
 await frames(100)
 check(not d.jammed and d.angle()< -1.6,"Forced door opens away from actor")
 print("DOORS RESULT ",7-failures,"/7")
 root.get_node("Sound").shutdown()
 world.queue_free()
 await process_frame
 await process_frame
 quit(1 if failures else 0)
