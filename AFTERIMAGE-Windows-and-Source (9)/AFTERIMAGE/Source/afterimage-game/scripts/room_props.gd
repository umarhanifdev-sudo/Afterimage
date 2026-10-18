class_name RoomProps
extends RefCounted
# Imported CC0 furniture, supported by authored rounded furniture and actual 3D clutter.
static var scenes = {}
static func imported(b, id: String, pos: Vector3, angle: float = 0, scale_value: Vector3 = Vector3.ONE):
	if not scenes.has(id): scenes[id] = load("res://assets/models/"+id+"/"+id+".gltf")
	var prop = scenes[id].instantiate()
	b.add_child(prop)
	prop.position = pos
	prop.rotation.y = angle
	prop.scale = scale_value
	var bounds = local_bounds(prop,prop)
	# Imported pivots are not a reliable floor or tabletop. Anchor the actual mesh.
	prop.position.y -= bounds.position.y*scale_value.y
	prop.set_meta("furniture_id",id)
	prop.set_meta("floor_y",pos.y)
	prop.set_meta("surface_y",prop.position.y+bounds.end.y*scale_value.y)
	var body = StaticBody3D.new()
	body.name = "FurnitureCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = prop.position
	body.rotation.y = angle
	b.add_child(body)
	var scaled = AABB(bounds.position*scale_value,bounds.size*scale_value)
	if id=="table":
		# The tabletop and four legs block bodies and bullets; the space beneath is open.
		var thick = .075*scale_value.y
		shape_box(body,Vector3(scaled.get_center().x,scaled.end.y-thick*.5,scaled.get_center().z),Vector3(scaled.size.x,thick,scaled.size.z))
		for x in [-1,1]:
			for z in [-1,1]:
				var leg_height = scaled.size.y-thick
				shape_box(body,Vector3(scaled.get_center().x+x*(scaled.size.x*.5-.10*scale_value.x),scaled.position.y+leg_height*.5,scaled.get_center().z+z*(scaled.size.z*.5-.09*scale_value.z)),Vector3(.10*scale_value.x,leg_height,.10*scale_value.z))
	elif id=="chair":
		# Seat, legs and back, rather than an invisible box spanning the empty arm space.
		var seat_y = scaled.position.y+scaled.size.y*.45
		shape_box(body,Vector3(scaled.get_center().x,seat_y,scaled.get_center().z),Vector3(scaled.size.x*.94,.10*scale_value.y,scaled.size.z*.92))
		shape_box(body,Vector3(scaled.get_center().x,scaled.position.y+scaled.size.y*.73,scaled.position.z+.055*scale_value.z),Vector3(scaled.size.x*.9,scaled.size.y*.54,.11*scale_value.z))
		for x in [-1,1]:
			for z in [-1,1]:
				shape_box(body,Vector3(scaled.get_center().x+x*scaled.size.x*.37,seat_y*.5,scaled.get_center().z+z*scaled.size.z*.34),Vector3(.08*scale_value.x,seat_y,.08*scale_value.z))
	else:
		shape_box(body,scaled.get_center(),scaled.size)
	var world_bounds = body.transform*scaled
	register_obstacle(b,world_bounds)
	prop.set_meta("collision_body",body)
	return prop

static func local_bounds(n: Node3D, top: Node3D) -> AABB:
	var result = AABB()
	if n is MeshInstance3D: result = top.global_transform.affine_inverse()*n.global_transform*n.get_aabb()
	for c in n.get_children():
		if c is Node3D:
			var child = local_bounds(c,top)
			if child.size.length_squared()>0: result = child if result.size.length_squared()==0 else result.merge(child)
	return result

static func shape_box(body: StaticBody3D, pos: Vector3, size: Vector3):
	var c = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	c.shape = shape
	c.position = pos
	body.add_child(c)

static func register_obstacle(b, bounds: AABB):
	var f = b.floor_index(bounds.position)
	b.obstacles.append({"floor":f,"rect":Rect2(Vector2(bounds.position.x-.43,bounds.position.z-.43),Vector2(bounds.size.x+.86,bounds.size.z+.86))})
static func soft(b, pos: Vector3, size: Vector3, color: Color, radius: float = .02):
	var prop = MeshInstance3D.new()
	prop.mesh = ServiceWeapon.rounded_box(size,minf(radius,minf(size.x,minf(size.y,size.z))*.4))
	prop.material_override = b.material(color)
	prop.set_meta("room_detail",true)
	prop.position = pos
	b.add_child(prop)
	return prop
static func collision(b, pos: Vector3, size: Vector3):
	var body = StaticBody3D.new()
	body.name = "PropCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var shape = CollisionShape3D.new()
	var bounds = BoxShape3D.new()
	bounds.size = size
	shape.shape = bounds
	body.add_child(shape)
	b.add_child(body)
	register_obstacle(b,AABB(pos-size*.5,size))
	return body
static func lathe(b, pos: Vector3, profile: Array, color: Color):
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var segments = 24
	for j in range(profile.size()-1):
		var slope = Vector2(profile[j+1].y-profile[j].y,profile[j].x-profile[j+1].x).normalized()
		for i in range(segments):
			for corner in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
				var angle = float(corner.x)/segments*TAU
				var ring = profile[corner.y]
				vertices.append(Vector3(cos(angle)*ring.x,ring.y,sin(angle)*ring.x))
				normals.append(Vector3(cos(angle)*slope.x,slope.y,sin(angle)*slope.x))
				uvs.append(Vector2(float(corner.x)/segments,float(corner.y)/profile.size()))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var prop = MeshInstance3D.new()
	prop.mesh = mesh
	prop.material_override = b.material(color)
	prop.set_meta("room_detail",true)
	prop.position = pos
	b.add_child(prop)
	return prop
static func cup(b, pos: Vector3):
	lathe(b,pos,[Vector2(.0,0),Vector2(.065,0),Vector2(.075,.12),Vector2(.065,.124),Vector2(.057,.015),Vector2(0,.015)],Color(.45,.42,.34))
	var handle = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = .029
	torus.outer_radius = .041
	torus.rings = 20
	torus.ring_segments = 8
	handle.mesh = torus
	handle.material_override = b.material(Color(.45,.42,.34))
	handle.position = pos+Vector3(.085,.068,0)
	handle.rotation.x = PI/2
	b.add_child(handle)
static func bottle(b, pos: Vector3, color: Color = Color(.09,.16,.11)):
	lathe(b,pos,[Vector2(0,0),Vector2(.055,0),Vector2(.06,.018),Vector2(.06,.19),Vector2(.025,.24),Vector2(.025,.33),Vector2(.03,.34),Vector2(.018,.34),Vector2(.018,.28)],color)
	lathe(b,pos,[Vector2(.061,.07),Vector2(.061,.15)],Color(.44,.41,.30))
static func plate(b, pos: Vector3):
	lathe(b,pos,[Vector2(0,.004),Vector2(.13,.004),Vector2(.18,.025),Vector2(.17,.035),Vector2(.12,.014),Vector2(0,.014)],Color(.58,.54,.43))
	soft(b,pos+Vector3(.04,.04,0),Vector3(.09,.028,.065),Color(.23,.16,.07),.015)
static func books(b,pos: Vector3,count: int = 4):
	for i in range(count):
		var p = pos+Vector3(i*.13,0,sin(i)*.03)
		soft(b,p+Vector3(0,.16,0),Vector3(.10,.32,.23),Color(.12+i*.017,.16,.13),.005)
		soft(b,p+Vector3(0,.16,-.118),Vector3(.065,.28,.006),Color(.45,.43,.34),.002)
		for yy in [.08,.25]: soft(b,p+Vector3(0,yy,.12),Vector3(.103,.008,.005),Color(.3,.28,.18),.002)
static func rug(b,pos: Vector3):
	var carpet = soft(b,pos+Vector3(0,.009,0),Vector3(3.0,.012,2.0),Color(.15,.10,.075),.004)
	for x in [-1.35,1.35]: soft(b,pos+Vector3(x,.018,0),Vector3(.035,.006,1.82),Color(.34,.25,.15),.002)
	for z in [-.88,.88]: soft(b,pos+Vector3(0,.018,z),Vector3(2.72,.006,.035),Color(.34,.25,.15),.002)
	for i in range(19):
		for z in [-1.05,1.05]: b.rod(pos+Vector3(-1.4+i*.155,.018,z-.04),pos+Vector3(-1.4+i*.155,.018,z+.04),.003,Color(.37,.31,.21))
static func lamp(b,pos: Vector3):
	lathe(b,pos,[Vector2(0,0),Vector2(.17,0),Vector2(.18,.025),Vector2(.10,.05),Vector2(.04,.12),Vector2(.025,.44)],Color(.2,.17,.10))
	var shade=lathe(b,pos,[Vector2(.24,.40),Vector2(.13,.70),Vector2(.12,.70),Vector2(.23,.40)],Color(.48,.4,.27))
	b.light(pos+Vector3(0,.52,0),Color(1,.62,.30),.65,3.5)
static func shelf(b,pos: Vector3):
	for x in [-.6,.6]: soft(b,pos+Vector3(x,1.1,0),Vector3(.08,2.2,.4),Color(.18,.13,.085))
	for y in [.08,.65,1.23,1.80,2.2]:
		soft(b,pos+Vector3(0,y,0),Vector3(1.3,.07,.46),Color(.22,.16,.1))
		if y<2: books(b,pos+Vector3(-.42,y+.04,0),3)
	collision(b,pos+Vector3(0,1.1,0),Vector3(1.25,2.2,.4))
static func curtains(b,pos: Vector3,side: int):
	for curtain in [-1,1]:
		var vertices=PackedVector3Array()
		var normals=PackedVector3Array()
		for y in range(12):
			for x in range(10):
				for c in [Vector2i(x,y),Vector2i(x+1,y),Vector2i(x+1,y+1),Vector2i(x,y),Vector2i(x+1,y+1),Vector2i(x,y+1)]:
					var across=float(c.x)/10
					var down=float(c.y)/12
					vertices.append(pos+Vector3(-side*(.12+sin(across*PI*6)*.045),1.15-down*2.65+sin(across*8)*.02,curtain*(.55+across*.48)))
					normals.append(Vector3(-side,0,0))
		var arrays=[]
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_NORMAL]=normals
		var mesh=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var node=MeshInstance3D.new()
		node.mesh=mesh
		var mat=b.material(Color(.17,.19,.16)).duplicate()
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		node.material_override=mat
		b.add_child(node)
static func bed(b,pos: Vector3, head_back: bool = false):
	var direction = -1.0 if head_back else 1.0
	var body = collision(b,pos+Vector3(0,.46,0),Vector3(1.5,.92,2.4))
	body.name = "BedCollision"
	soft(b,pos+Vector3(0,.42,0),Vector3(1.5,.20,2.4),Color(.13,.12,.09),.035)
	soft(b,pos+Vector3(0,.65,0),Vector3(1.4,.28,2.3),Color(.46,.45,.36),.10)
	for x in [-.29,.29]: soft(b,pos+Vector3(x,.84,.76*direction),Vector3(.53,.19,.49),Color(.59,.58,.48),.08)
	soft(b,pos+Vector3(0,.82,-.25*direction),Vector3(1.43,.12,1.61),Color(.20,.27,.25),.048)
	for i in range(12): b.rod(pos+Vector3(-.67,.889,(-.94+i*.11)*direction),pos+Vector3(.67,.889+sin(i)*.004,(-.94+i*.11)*direction),.004,Color(.17,.22,.2))
	for side in [-1,1]:
		for end in [-1,1]: b.rod(pos+Vector3(side*.66,0,end*1.1),pos+Vector3(side*.66,.98,end*1.1),.027,Color(.2,.21,.18))
		b.rod(pos+Vector3(-.66,.94,side*1.1),pos+Vector3(.66,.94,side*1.1),.027,Color(.2,.21,.18))
	for i in range(7): b.rod(pos+Vector3(-.55+i*.18,.52,1.1*direction),pos+Vector3(-.55+i*.18,.94,1.1*direction),.012,Color(.22,.23,.2))

static func bedroom(b,pos: Vector3,wall_z: float,medical: bool = false):
	# Adapt the supplied plan to the existing room doorway: headboard at the back,
	# two bedside tables, perimeter storage, window/side desk and a clear entrance.
	var anchor = Vector3(pos.x,pos.y,wall_z+1.30)
	if not medical or b.chapter>=2:
		if medical: b.make_bed(anchor,true)
		else: bed(b,anchor,true)
		b.bed_layouts.append({"anchor":anchor,"wall_z":wall_z,"medical":medical})
	for side in [-1,1]:
		var stand = anchor+Vector3(side*1.1,0,-.88)
		b.box(stand+Vector3.UP*.31,Vector3(.5,.62,.48),Color(.20,.15,.10))
		soft(b,stand+Vector3(0,.35,.249),Vector3(.39,.23,.016),Color(.29,.23,.15),.006)
		if not medical or side<0: lamp(b,stand+Vector3.UP*.62)
	if medical:
		b.memory_bed_anchor = anchor
		b.memory_wristband_pos = anchor+Vector3(1.1,.6325,-.88)
	var side = -1.0 if pos.x<0 else 1.0
	var wardrobe = Vector3(side*11.95,pos.y,wall_z+1.7)
	b.box(wardrobe+Vector3.UP*1.15,Vector3(.8,2.3,2.65),Color(.16,.13,.09))
	for z in [-.66,.66]:
		soft(b,wardrobe+Vector3(-side*.411,1.15,z),Vector3(.025,2.13,1.22),Color(.22,.18,.12),.008)
		b.rod(wardrobe+Vector3(-side*.445,1.05,z-.05),wardrobe+Vector3(-side*.445,1.28,z-.05),.012,Color(.4,.35,.22))
	var desk = imported(b,"table",Vector3(side*6.43,pos.y,wall_z+1.6),PI/2,Vector3(.8,1.3,.9))
	books(b,Vector3(side*6.43,float(desk.get_meta("surface_y")),wall_z+1.6),2)
	var end_z = pos.z+5.09 if pos.z<25 else 35.86
	var dresser = Vector3(pos.x,pos.y,end_z-.27)
	b.box(dresser+Vector3.UP*.4,Vector3(2.5,.8,.5),Color(.22,.17,.11))
	for x in [-.62,.62]:
		for y in [.22,.57]:
			soft(b,dresser+Vector3(x,y,-.26),Vector3(1.13,.27,.025),Color(.3,.23,.15),.006)
			b.rod(dresser+Vector3(x-.12,y,-.285),dresser+Vector3(x+.12,y,-.285),.012,Color(.4,.35,.22))
static func fireplace(b,pos: Vector3):
	collision(b,pos+Vector3(0,.74,0),Vector3(1.9,1.48,.75))
	soft(b,pos+Vector3(0,1.4,0),Vector3(1.9,.15,.62),Color(.21,.2,.17),.035)
	for side in [-1,1]:
		soft(b,pos+Vector3(side*.73,.675,0),Vector3(.29,1.35,.48),Color(.22,.21,.18),.025)
		for i in range(7): soft(b,pos+Vector3(side*.73,.12+i*.18,-.25),Vector3(.3,.012,.016),Color(.1,.09,.07),.003)
	soft(b,pos+Vector3(0,.11,0),Vector3(1.9,.15,.75),Color(.2,.18,.15),.025)
	soft(b,pos+Vector3(0,.7,.20),Vector3(1.2,1.3,.05),Color(.025,.025,.022))
	for i in range(4):
		var log=b.rod(pos+Vector3(-.45,.24,-.15+i*.1),pos+Vector3(.45,.24,-.15+i*.1),.065,Color(.07,.05,.03))
static func room(b,pos: Vector3,floor_id: int):
	var type = (int(pos.z/8)+floor_id)%3
	var wall_z = .14 if pos.z<8 else pos.z-2.69
	if floor_id==3 and pos.x<0 and pos.z>27:
		bedroom(b,pos,wall_z,true)
		return
	# Leave a broad corridor from the door to each important memory detail.
	rug(b,pos+Vector3(0,0,1.4))
	if type==0:
		var table = imported(b,"table",pos,0,Vector3(1,1.68,1.6))
		imported(b,"chair",pos+Vector3(.45,0,1.15),PI+.12)
		imported(b,"chair",pos+Vector3(-.5,0,-1.1),-.15)
		var top = float(table.get_meta("surface_y"))-pos.y
		plate(b,pos+Vector3(-.35,top,0));cup(b,pos+Vector3(.45,top,.15));bottle(b,pos+Vector3(.2,top,-.18))
		shelf(b,pos+Vector3(-1.8,0,-1.75))
	elif type==1:
		imported(b,"sofa",pos+Vector3(0,0,1.9),PI)
		var table = imported(b,"table",pos+Vector3(0,0,.5))
		var top = float(table.get_meta("surface_y"))-pos.y
		cup(b,pos+Vector3(.35,top,.5));bottle(b,pos+Vector3(-.5,top,.48))
		soft(b,pos+Vector3(-.1,top+.0125,.5),Vector3(.33,.025,.22),Color(.4,.38,.3),.003)
		fireplace(b,Vector3(pos.x,pos.y,wall_z+.38))
		lamp(b,Vector3(pos.x-.68,pos.y+1.475,wall_z+.38))
	else:
		bedroom(b,pos,wall_z)
	# A framed, faded family portrait and a packed bag reinforce evacuation.
	var frame=soft(b,Vector3(pos.x+.9,pos.y+1.65,wall_z+.028),Vector3(.62,.76,.055),Color(.16,.105,.065),.02)
	soft(b,Vector3(pos.x+.9,pos.y+1.65,wall_z+.06),Vector3(.49,.63,.01),Color(.28,.27,.21),.005)
	var bag=soft(b,pos+Vector3(1.35,.22,-1.3),Vector3(.55,.42,.34),Color(.20,.19,.12),.08)
	collision(b,pos+Vector3(1.35,.21,-1.3),Vector3(.55,.42,.34))
	for x in [-.16,.16]: b.rod(pos+Vector3(1.35+x,.26,-1.48),pos+Vector3(1.35+x,.43,-1.48),.012,Color(.09,.08,.05))

static func batch(b):
	# Repeated small furniture parts share draw calls, partitioned by floor.
	var groups = {}
	for n in b.get_children():
		if n is MeshInstance3D and n.has_meta("room_detail"):
			var key = str(n.mesh.get_rid())+str(n.material_override.get_rid())+str(Vector3i(floori(n.position.x/8),floori(n.position.y/4.5),floori(n.position.z/8)))
			if not groups.has(key): groups[key] = []
			groups[key].append(n)
	for group in groups.values():
		if group.size()<3: continue
		var mesh = MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = group[0].mesh
		mesh.instance_count = group.size()
		for i in range(group.size()): mesh.set_instance_transform(i,group[i].transform)
		var instance = MultiMeshInstance3D.new()
		instance.multimesh = mesh
		instance.material_override = group[0].material_override
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.add_child(instance)
		for n in group:
			b.remove_child(n)
			n.queue_free()
