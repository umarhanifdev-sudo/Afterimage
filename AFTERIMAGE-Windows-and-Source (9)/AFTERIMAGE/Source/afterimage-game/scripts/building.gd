class_name MemoryBuilding
extends Node3D
const FLOOR_H = 4.5
const FLOOR_NAMES = ["ENTRY", "UNCERTAINTY", "RESISTANCE", "REMEMBRANCE"]
const PALE = Color(.46,.46,.39)
const WALL = Color(.38,.40,.35)
const DARK = Color(.045,.052,.054)
const WOOD = Color(.25,.21,.16)
const RED = Color(.31,.055,.035)
var chapter = 0
var obstacles: Array[Dictionary] = []
var interactables: Array[Dictionary] = []
var hazards: Array[Vector3] = []
var lamps: Array[Dictionary] = []
var doors: Array[MemoryDoor] = []
var fires: Array[Dictionary] = []
var grids: Array[AStarGrid2D] = []
var grid: AStarGrid2D
var mats = {}
var elapsed = 0.0
var fire_pressure = 0.0
var next_spread = 42.0
var collapsed = false
var exit_door: MemoryDoor
var rng = RandomNumberGenerator.new()
var memory_bed_anchor = Vector3.ZERO
var memory_wristband_pos = Vector3.ZERO
var mounted_panels: Array[Dictionary] = []
var bed_layouts: Array[Dictionary] = []
var light_budget_time = 0.0
var active_lamps: Array[Dictionary] = []
var ambient_particles: Array[CPUParticles3D] = []

func floor_index(pos: Vector3) -> int:
	return clampi(roundi(pos.y/FLOOR_H),0,3)

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key = str(color)+str(glow)
	if mats.has(key): return mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .88
	if glow>0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	mats[key] = m
	return m

func surface(id: String, tint: Color, tiling: float = .5) -> StandardMaterial3D:
	if mats.has(id): return mats[id]
	var m = StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = .88
	var base = "res://assets/materials/"+id
	if ResourceLoader.exists(base+"_diff.jpg"):
		m.albedo_texture = load(base+"_diff.jpg")
		m.normal_enabled = true
		m.normal_texture = load(base+"_nor_gl.jpg")
		m.normal_scale = .32
		m.roughness_texture = load(base+"_rough.jpg")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE*tiling
	mats[id] = m
	return m

func box(pos: Vector3, size: Vector3, color: Color, solid: bool = true, navigation: bool = true) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = material(color)
	m.position = pos
	add_child(m)
	if solid:
		var body = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		m.add_child(body)
		var f = floor_index(pos-Vector3(0,size.y*.5,0))
		if navigation and pos.y-size.y*.5<f*FLOOR_H+1.8 and pos.y+size.y*.5>f*FLOOR_H+.25:
			obstacles.append({"floor":f,"rect":Rect2(Vector2(pos.x-size.x*.5-.28,pos.z-size.z*.5-.28),Vector2(size.x+.56,size.z+.56))})
	return m

func wall(pos: Vector3, size: Vector3):
	var m = box(pos,size,WALL)
	m.material_override = surface("painted_plaster_wall",Color(.61,.63,.57))
	var base = pos.y-size.y*.5
	var panel = box(Vector3(pos.x,base+.62,pos.z),Vector3(size.x+.025,1.24,size.z+.025),WOOD,false)
	panel.material_override = surface("worn_planks",Color(.32,.29,.24),.7)
	box(Vector3(pos.x,base+1.28,pos.z),Vector3(size.x+.07,.065,size.z+.07),Color(.12,.12,.105),false)

func rod(a: Vector3, b: Vector3, radius: float, color: Color):
	var m = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	m.mesh = mesh
	m.material_override = material(color)
	m.position = (a+b)*.5
	add_child(m)
	var dir = (b-a).normalized()
	m.quaternion = Quaternion(Vector3.UP,dir)
	return m

func label_at(text: String, pos: Vector3, scale_size: float = .005, color: Color = Color(.68,.68,.53)):
	var l = Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/BebasNeue-Regular.ttf")
	l.font_size = 64
	l.pixel_size = scale_size
	l.outline_size = 3
	l.outline_modulate = Color(.02,.025,.03)
	l.no_depth_test = false
	l.modulate = color
	l.position = pos
	l.rotation.y = PI
	add_child(l)
	return l

func light(pos: Vector3, color: Color, energy: float, reach: float, flicker: bool = false):
	var l = OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.4
	l.light_cull_mask = 1
	add_child(l)
	lamps.append({"node":l,"energy":energy,"flicker":flicker,"floor":floor_index(pos-Vector3(0,2,0))})
	return l

func build(index: int):
	chapter = index
	rng.seed = 1941
	for f in range(4):
		make_floor(f)
		if f<3: staircase(f)
	make_clues()
	memory_details()
	var spots = [Vector3(-5,.08,17),Vector3(10,.08,25),Vector3(10.4,4.58,9),Vector3(-5,9.08,8),Vector3(5.1,9.08,26),Vector3(-9.5,9.08,29),Vector3(10.5,13.58,6)]
	for pos in spots: fire(pos,.6 if chapter==3 else 1.0)
	build_navigation()
	RoomProps.batch(self)
	batch_architecture()

func make_floor(f: int):
	var y = f*FLOOR_H
	for side in [-1,1]:
		box(Vector3(side*7.25,y-.16,18),Vector3(10.5,.32,36),DARK,true,false).material_override = surface("concrete_floor_02",Color(.62,.64,.62),.6)
		wall(Vector3(side*12.5,y+2.1,18),Vector3(.3,4.2,36))
		for span in [[0.0,8.5],[24.0,36.0]]:
			wall(Vector3(side*2.25,y+2.1,(span[0]+span[1])*.5),Vector3(.24,4.2,span[1]-span[0]))
		var last = 0.0
		for z in [6.0,14.0,22.0,30.0]:
			wall(Vector3(side*6,y+2.1,(last+z-.96)*.5),Vector3(.24,4.2,z-.96-last))
			wall(Vector3(side*6,y+3.5,z),Vector3(.24,1.4,1.92))
			var d = make_door(Vector3(side*6,y,z+.9),PI/2,"room_%d_%d_%d"%[f,side,int(z)])
			d.jammed = f==2 and side==1 and z==22
			if z==14 or (f==0 and side==-1 and z==6): d.target_angle = -1.5
			last = z+.96
			for dz in [-1.02,1.02]: box(Vector3(side*6,y+1.4,z+dz),Vector3(.34,2.8,.08),WOOD,false)
			box(Vector3(side*6,y+2.82,z),Vector3(.34,.08,2.1),WOOD,false)
			if z<30: wall(Vector3(side*9.25,y+2.1,z+4),Vector3(6.4,4.2,.22))
			furniture(Vector3(side*9.3,y,z-1.2),f)
			window_bay(Vector3(side*12.28,y+2.5,z),side)
		wall(Vector3(side*6,y+2.1,(last+36)*.5),Vector3(.24,4.2,36-last))
		for z in [4,17,32]:
			box(Vector3(side*4.1,y+4.09,z),Vector3(.6,.27,.28),Color(.29,.27,.20),false)
			box(Vector3(side*4.1,y+3.94,z),Vector3(.4,.045,.2),Color(1,.66,.31) if f%2==0 else Color(.49,.67,.78),false).material_override = material(Color(1,.62,.28) if f%2==0 else Color(.47,.62,.73),2)
			var l = light(Vector3(side*4.1,y+3.65,z),Color(1,.58,.29) if f%2==0 else Color(.38,.56,.76),1.5,8.2,true)
			l.shadow_enabled = false
			rod(Vector3(side*5.7,y+3.8,z-2),Vector3(side*5.2,y+2.7,z-.7),.015,DARK)
			rod(Vector3(side*5.2,y+2.7,z-.7),Vector3(side*5.6,y+3.6,z+1),.015,DARK)
		for z in range(3,36,4):
			box(Vector3(side*4.1,y+4.17,z),Vector3(3.5,.22,.24),WOOD,false)
			box(Vector3(side*5.8,y+1.6,z),Vector3(.1,3.2,.17),WOOD,false)
			box(Vector3(side*3.1,y+.014,z),Vector3(.08,.012,.8),Color(.33,.35,.29),false)
		for i in range(27):
			var pos = Vector3(side*rng.randf_range(2.7,5.7),y+.035,rng.randf_range(1.5,35))
			var debris = box(pos,Vector3(rng.randf_range(.06,.35),rng.randf_range(.04,.14),rng.randf_range(.12,.55)),Color(.18,.17,.135),false)
			debris.rotation = Vector3(rng.randf_range(-.3,.3),rng.randf()*PI,.15)
			if i%3==0:
				var paper = box(pos+Vector3(.3,.01,.2),Vector3(.24,.008,.34),Color(.45,.43,.34),false)
				paper.position.y = y+.005
				paper.rotation.y = rng.randf()*PI
		for i in range(5):
			var z = 2+i*7.0
			stain(Vector3(side*5.86,y+1.8,z),side)
			for k in range(3):
				rod(Vector3(side*5.85,y+2.0+k*.12,z-.16),Vector3(side*5.85,y+1.85+k*.14,z+.2),.008,Color(.08,.07,.06))
			if i%2==0: web(Vector3(side*5.8,y+4.02,z))
		var cabinet = box(Vector3(side*5.35,y+.65,27.3),Vector3(.7,1.3,1.0),Color(.12,.15,.14))
		for yy in [.25,.65,1.05]:
			box(Vector3(side*4.97,y+yy,27.3),Vector3(.035,.32,.83),Color(.19,.21,.18),false)
			box(Vector3(side*4.94,y+yy,27.3),Vector3(.025,.035,.22),PALE,false)
		for k in range(5):
			var beam = box(Vector3(side*5.25,y+.065+k*.13,19+k*.25),Vector3(.13,.13,1.7),DARK)
			beam.rotation.y = side*(.2+k*.15)
		# End walls and continuous ceilings for the two side wings.
		box(Vector3(side*7.3,y+4.3,18),Vector3(10.4,.15,36),DARK,true,false)
	wall(Vector3(0,y+2.1,.0),Vector3(25,4.2,.28))
	wall(Vector3(0,y+2.1,36),Vector3(25,4.2,.28))
	for span in [[0,11.8],[22,36]]:
		box(Vector3(0,y-.16,(span[0]+span[1])*.5),Vector3(4,.32,span[1]-span[0]),DARK,true,false).material_override = surface("concrete_floor_02",Color(.62,.64,.62))
	if f==0: box(Vector3(0,-.16,16.9),Vector3(4,.32,10.2),DARK,true,false)
	if f==3: box(Vector3(0,y+4.3,18),Vector3(4.2,.15,36),DARK,true,false)
	for side in [-1,1]:
		box(Vector3(side*2.15,y+.32,17),Vector3(.14,.64,10),WOOD)
		rod(Vector3(side*2.15,y+1.07,12),Vector3(side*2.15,y+1.07,22),.035,Color(.15,.15,.13))
		for z in range(12,23,2): rod(Vector3(side*2.15,y+.3,z),Vector3(side*2.15,y+1.07,z),.025,DARK)
	for side in [-1,1]:
		box(Vector3(side*4.1,y+3.7,8.5),Vector3(2.8,.65,.06),DARK,false)
		for offset in [-.8,.8]: rod(Vector3(side*4.1+offset,y+4.025,8.5),Vector3(side*4.1+offset,y+4.225,8.5),.012,DARK)
	label_at("%02d / %s"%[f+1,FLOOR_NAMES[f]],Vector3(-4.1,y+3.82,8.4),.006)
	label_at("STAIRS  >",Vector3(-4.1,y+3.5,8.4),.004)
	label_at("<  STAIRS",Vector3(4.1,y+3.5,8.4),.004)
	label_at("EVACUATION  >",Vector3(-4.1,y+2.4,25),.0035)
	box(Vector3(-5.63,y+1.25,10.8),Vector3(.5,.6,.25),Color(.11,.19,.17))
	light(Vector3(-5.1,y+1.5,10.6),Color(.28,.72,.54),.25,2.3)
	add_interaction("charger_%d"%f,"HOLD E / CHARGE FLASHLIGHT",Vector3(-5.1,y+1.3,10.7))
	label_at("HAND GENERATOR",Vector3(-5.1,y+1.95,11),.0028)
	box(Vector3(4.9,y+.325,2.8),Vector3(.68,.65,.48),WOOD)
	box(Vector3(4.9,y+.8,2.8),Vector3(.6,.3,.4),Color(.2,.26,.18))
	add_interaction("ammo_%d"%f,"TAKE AMMUNITION",Vector3(4.9,y+1.0,2.8))
	box(Vector3(-7.0,y+.45,11.2),Vector3(.55,.9,.5),WOOD)
	box(Vector3(-7.0,y+.975,11.2),Vector3(.25,.15,.18),Color(.49,.41,.20),false)
	add_interaction("battery_%d"%f,"TAKE FLASHLIGHT CELL",Vector3(-7.0,y+1.2,11.2))
	if f==0 or f==2:
		box(Vector3(-5,y+.25,33),Vector3(.65,.5,.38),WOOD)
		box(Vector3(-5,y+.7,33),Vector3(.6,.4,.3),Color(.57,.52,.4),false)
		box(Vector3(-5,y+.7,32.84),Vector3(.1,.27,.02),RED,false)
		box(Vector3(-5,y+.7,32.83),Vector3(.3,.09,.02),RED,false)
		add_interaction("health_%d"%f,"USE FIELD DRESSING",Vector3(-5,y+.9,32.7))
	particles(Vector3(-4,y+2,18),"smoke_04",10,8,Color(.18,.21,.24,.035),2.4,Vector3(0,.02,0)).emission_box_extents = Vector3(1,1,15)
	particles(Vector3(4,y+2.7,18),"spark_01",22,9,Color(.50,.48,.4,.15),.022,Vector3(0,.07,0)).emission_box_extents = Vector3(1,1,15)

func make_door(pos: Vector3, yaw: float, id: String) -> MemoryDoor:
	var d = MemoryDoor.new()
	d.identity = id
	d.position = pos
	d.rotation.y = yaw
	d.wood = surface("worn_planks",Color(.32,.29,.24),.7)
	add_child(d)
	doors.append(d)
	return d

func staircase(f: int):
	var y = f*FLOOR_H
	ramp(Vector3(-1.06,y,11.8),Vector3(-1.06,y+2.25,20))
	box(Vector3(0,y+2.1,20.95),Vector3(4.1,.3,1.9),WOOD,true,false).material_override = surface("worn_planks",Color(.32,.29,.24),.7)
	ramp(Vector3(1.06,y+2.25,20),Vector3(1.06,y+4.5,11.8))
	for side in [-1,1]:
		var a = Vector3(side*1.92,y+1.0 if side==-1 else y+5.5,11.8)
		var b = Vector3(side*1.92,y+3.25,20)
		rod(a,b,.035,Color(.18,.17,.14))
		for t in range(9):
			var p = a.lerp(b,t/8.0)
			rod(p-Vector3(0,1,0),p,.022,DARK)
	label_at("%02d"%(f+2),Vector3(0,y+3.7,21.9),.009)
	light(Vector3(0,y+3.9,20.8),Color(.34,.49,.64),1.2,6)

func ramp(a: Vector3, b: Vector3):
	var w = .94
	var verts = PackedVector3Array([a+Vector3(-w,-.02,0),b+Vector3(-w,-.02,0),b+Vector3(w,-.02,0),a+Vector3(-w,-.02,0),b+Vector3(w,-.02,0),a+Vector3(w,-.02,0)])
	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(verts)
	shape.backface_collision = true
	col.shape = shape
	body.add_child(col)
	add_child(body)
	for i in range(24):
		var p = a.lerp(b,(i+.5)/24.0)
		box(p-Vector3(0,.08,0),Vector3(w*2,.15,absf(b.z-a.z)/24+.025),WOOD,false).material_override = surface("worn_planks",Color(.32,.29,.24),.7)

func furniture(pos: Vector3, f: int):
	RoomProps.room(self,pos,f)

func desk(pos: Vector3):
	var table = RoomProps.imported(self,"table",pos,0,Vector3(1,1.68,1.6))
	RoomProps.soft(self,Vector3(pos.x+.3,float(table.get_meta("surface_y"))+.02,pos.z-.1),Vector3(.35,.04,.28),Color(.47,.43,.32),.004)

func window_bay(pos: Vector3, side: int):
	RoomProps.curtains(self,pos,side)
	box(pos,Vector3(.035,2.1,1.5),DARK,false).material_override = material(Color(.075,.13,.19),.6)
	for dz in [-.8,0,.8]: box(pos+Vector3(-side*.04,0,dz),Vector3(.1,2.2,.07),WOOD,false)
	box(pos+Vector3(-side*.04,0,0),Vector3(.1,.08,1.7),WOOD,false)
	light(pos+Vector3(-side*.7,0,0),Color(.26,.42,.63),1.0,6)

func stain(pos: Vector3, side: int):
	var m = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(rng.randf_range(.6,1.4),rng.randf_range(.9,2.1))
	m.mesh = q
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/particles/smoke_04.png")
	mat.albedo_color = Color(.065,.045,.03,.78)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.position = pos
	m.rotation.y = PI/2
	add_child(m)
	# Branching cracks: fine lines break up the broad plaster surface.
	var a = pos+Vector3(-side*.002,.48,.15)
	for i in range(4):
		var b = a+Vector3(0,-.16,rng.randf_range(-.12,.12))
		rod(a,b,.006,Color(.07,.065,.05))
		if i==2: rod(b,b+Vector3(0,-.06,.22),.004,Color(.09,.08,.06))
		a = b

func web(pos: Vector3):
	for k in range(5):
		var end = pos+Vector3(-.65,k*-.13,.65-k*.13)
		rod(pos,end,.003,Color(.27,.28,.25))
	for k in range(1,4): rod(pos+Vector3(-k*.15,-k*.13,0),pos+Vector3(-k*.15,0,k*.13),.002,Color(.27,.28,.25))

func make_clues():
	box(Vector3(-9.3,1.007,4.8),Vector3(.46,.17,.32),PALE,false)
	box(Vector3(-9.3,1.098,4.8),Vector3(.3,.012,.23),Color(.13,.16,.17),false)
	add_interaction("photo","EXAMINE THE PHOTOGRAPH",Vector3(-9.3,1.3,4.8),"THE PHOTOGRAPH","There are names on the back. Why did I only remember uniforms?")
	desk(Vector3(0,4.5,29))
	add_interaction("manifest","READ THE EVACUATION LIST",Vector3(0,5.65,29),"THE LIST","This was an evacuation point. The arrows were pointing the same way we were going.")
	label_at("EVACUATION REGISTER",Vector3(0,7,35.7),.006)
	var panel = box(Vector3(5.73,6.0,23.4),Vector3(.30,.75,.55),Color(.18,.21,.18))
	box(Vector3(5.55,6.0,23.4),Vector3(.06,.28,.15),RED,false)
	var sign = label_at("EXIT CIRCUIT",Vector3(5.86,6.7,23.4),.0035)
	sign.rotation.y = -PI/2
	mounted_panels.append({"node":panel,"wall_x":5.88,"back_x":5.88})
	add_interaction("power","RESTORE EXIT POWER",Vector3(5.48,6.0,23.4))
	exit_door = make_door(Vector3(3.2,13.5,34),0,"fire_exit")
	exit_door.locked = chapter<3
	for side in [-1,1]: box(Vector3(4.1+side*1.5,15,34),Vector3(.96,3,.25),DARK)
	label_at("EXIT",Vector3(4.1,16.7,33.9),.007,Color(.48,.7,.56))
	light(Vector3(4.1,16.4,33.3),Color(.35,.68,.51),.75,5)
	add_interaction("exit","LEAVE THROUGH THE FIRE DOOR",Vector3(4.1,15,33.55))
	if chapter>=2:
		add_interaction("wristband","READ THE WRISTBAND",memory_wristband_pos+Vector3.UP*.13,"THE WRISTBAND","Milo. Seventy-eight. That isn't his name. It's mine.")
		box(memory_wristband_pos,Vector3(.23,.025,.1),Color(.8,.77,.62),false)
		light(Vector3(-9.5,16,30.5),Color(1,.74,.46),1.1,5)

func add_interaction(id: String, prompt: String, pos: Vector3, title: String = "", line: String = ""):
	interactables.append({"id":id,"prompt":prompt,"pos":pos,"title":title,"line":line,"used":false})
func make_bed(pos: Vector3, head_back: bool = false):
	RoomProps.bed(self,pos,head_back)
	var stand = pos+Vector3(1.65,0,-.8) if head_back else pos+Vector3(1.1,0,.8)
	rod(stand,stand+Vector3.UP*2.8,.018,Color(.45,.48,.45))
	RoomProps.soft(self,stand+Vector3.UP*2.45,Vector3(.21,.37,.10),Color(.47,.55,.51),.04)

func particles(pos: Vector3, tex: String, count: int, life: float, color: Color, size: float, speed: Vector3):
	var p = CPUParticles3D.new()
	p.position = pos
	p.amount = count
	p.lifetime = life
	p.preprocess = life
	p.direction = Vector3.UP
	p.spread = 18
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = speed.y*.7
	p.initial_velocity_max = speed.y*1.3
	p.scale_amount_min = size*.65
	p.scale_amount_max = size
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(.6,.08,.6)
	var mesh = QuadMesh.new()
	mesh.size = Vector2(1,1)
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = load("res://assets/particles/"+tex+".png")
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mat.no_depth_test = false
	mesh.material = mat
	p.mesh = mesh
	var grad = Gradient.new()
	grad.set_color(0,Color(1,1,1,.8))
	grad.set_color(1,Color(1,1,1,0))
	p.color_ramp = grad
	add_child(p)
	ambient_particles.append(p)
	return p

func fire(pos: Vector3, strength: float = 1.0):
	hazards.append(pos)
	box(pos-Vector3(0,.04,0),Vector3(1.7,.03,1.6),Color(.03,.025,.022),false)
	var flame = particles(pos,"flame_01",18,1.3,Color(1,.39,.09),1.35*strength,Vector3(0,2.1,0))
	particles(pos+Vector3(0,1.9,0),"smoke_04",12,2.4,Color(.12,.13,.14,.19),1.7,Vector3(0,.6,0))
	particles(pos,"spark_01",12,2,Color(1,.49,.12),.055,Vector3(0,2.8,0))
	var l = light(pos+Vector3(0,1.8,0),Color(1,.28,.06),2.1*strength,7,true)
	fires.append({"node":flame,"light":l,"strength":strength})

func _process(dt):
	elapsed += dt
	fire_pressure = lerpf(fire_pressure,minf(.8,GameState.kills*.045+elapsed*.0008),dt*.15)
	var game = get_parent().get_parent()
	var viewer = game.get("player")
	var active_camera = get_viewport().get_camera_3d()
	if is_instance_valid(active_camera): viewer = active_camera
	light_budget_time -= dt
	if light_budget_time<=0:
		light_budget_time = .12
		active_lamps.clear()
		var view_pos = viewer.global_position if is_instance_valid(viewer) else Vector3(-4,0,3)
		var candidates = lamps.duplicate()
		candidates.sort_custom(func(a,b):return a.node.position.distance_squared_to(view_pos)*(.8 if a.node.visible else 1.0)<b.node.position.distance_squared_to(view_pos)*(.8 if b.node.visible else 1.0))
		for l in candidates:
			# A hard, local light budget avoids dozens of competing light passes.
			l.node.visible = active_lamps.size()<12 and absf(l.node.position.y-view_pos.y)<5.0 and l.node.position.distance_squared_to(view_pos)<225
			if l.node.visible: active_lamps.append(l)
		ambient_particles = ambient_particles.filter(func(p):return is_instance_valid(p) and not p.one_shot)
		for p in ambient_particles:
			if is_instance_valid(p) and not p.one_shot:
				p.visible = absf(p.position.y-view_pos.y)<5 and p.position.distance_squared_to(view_pos)<625
	for i in range(active_lamps.size()):
		var l = active_lamps[i]
		var flicker = 1.0+sin(elapsed*3.1+l.node.position.z)*.035 if l.flicker else 1.0
		l.node.light_energy = l.energy*flicker
	for f in fires: f.node.scale = Vector3.ONE*(1+fire_pressure*.5)
	if elapsed>next_spread and fires.size()<11 and chapter<3:
		next_spread += 42
		var spots = [Vector3(-10.5,.08,19),Vector3(10.4,9.08,16),Vector3(-10.5,4.58,34),Vector3(9,13.58,12)]
		fire(spots[fires.size()-7],.6)
	if not collapsed and fire_pressure>.24:
		collapsed = true
		var beam = RigidBody3D.new()
		beam.collision_layer = 1
		beam.collision_mask = 1
		beam.position = Vector3(-9,12.8,19)
		var mesh = MeshInstance3D.new()
		var b = BoxMesh.new()
		b.size = Vector3(2.7,.18,.21)
		mesh.mesh = b
		mesh.material_override = material(DARK)
		beam.add_child(mesh)
		var c = CollisionShape3D.new()
		var s = BoxShape3D.new()
		s.size = b.size
		c.shape = s
		beam.add_child(c)
		add_child(beam)
		beam.angular_velocity = Vector3(.7,.2,.8)
		Sound.at("collapse",beam.global_position,.85)

func build_navigation():
	for f in range(4):
		var g = AStarGrid2D.new()
		g.region = Rect2i(-12,1,25,35)
		g.cell_size = Vector2.ONE
		g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		g.update()
		for x in range(-12,13):
			for z in range(1,36):
				var blocked = abs(x)<2 and z>=12 and z<=22
				for o in obstacles:
					if o.floor==f and o.rect.has_point(Vector2(x,z)):
						blocked = true
						break
				g.set_point_solid(Vector2i(x,z),blocked)
		grids.append(g)
	grid = grids[0]

func nav_cell(pos: Vector3, f: int = -1) -> Vector2i:
	if f<0: f = floor_index(pos)
	var g = grids[f]
	var p = Vector2i(clampi(roundi(pos.x),-12,12),clampi(roundi(pos.z),1,35))
	if not g.is_point_solid(p): return p
	for radius in range(1,5):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var q = p+Vector2i(x,z)
				if g.is_in_boundsv(q) and not g.is_point_solid(q): return q
	return p

func flat_route(a: Vector3, b: Vector3, f: int) -> PackedVector3Array:
	var points = PackedVector3Array()
	for p in grids[f].get_point_path(nav_cell(a,f),nav_cell(b,f)):
		points.append(Vector3(p.x,f*FLOOR_H,p.y))
	return points

func route(a: Vector3, b: Vector3) -> PackedVector3Array:
	var from = floor_index(a)
	var to = floor_index(b)
	var result = PackedVector3Array()
	var cursor = a
	while from!=to:
		var up = from<to
		var y = from*FLOOR_H
		var entry = Vector3(-1.06 if up else 1.06,y,11.2)
		result.append_array(flat_route(cursor,entry,from))
		var base = y if up else y-FLOOR_H
		var flight = PackedVector3Array([Vector3(-1.06,base,11.8),Vector3(-1.06,base+2.25,20.8),Vector3(1.06,base+2.25,20.8),Vector3(1.06,base+4.5,11.2)])
		if not up: flight.reverse()
		result.append_array(flight)
		from += 1 if up else -1
		cursor = flight[-1]
	result.append_array(flat_route(cursor,b,to))
	return result

func memory_details():
	# A fixed event, reconstructed differently. The clock is never a game timer.
	rod(Vector3(4.1,3.1,8.5),Vector3(4.1,3.38,8.5),.018,DARK)
	box(Vector3(4.1,2.8,8.47),Vector3(.55,.6,.035),Color(.33,.30,.23),false)
	box(Vector3(4.1,2.8,8.44),Vector3(.46,.51,.015),Color(.59,.54,.4),false)
	var hand = box(Vector3(4.1,2.88,8.42),Vector3(.014,.19,.01),DARK,false)
	hand.rotation.z = -.15+chapter*.8
	var short_hand = box(Vector3(4.15,2.8,8.41),Vector3(.14,.015,.01),DARK,false)
	short_hand.rotation.z = chapter*-.53
	if chapter>=1:
		label_at("DO NOT SEPARATE FAMILIES",Vector3(0,6.5,35.65),.004)
	if chapter>=2:
		box(Vector3(-4.85,14.4,26),Vector3(.45,.75,.35),Color(.52,.54,.48),false)
		box(Vector3(-4.85,14.64,25.8),Vector3(.34,.23,.025),Color(.06,.17,.13),false).material_override = material(Color(.08,.22,.15),.7)
		rod(Vector3(-4.85,14.2,26),Vector3(-4.85,13.6,26),.035,PALE)
	if chapter==3:
		label_at("MILO",Vector3(-9,15.5,31.6),.004,Color(.62,.67,.61))

func batch_architecture():
	# Bake immobile opaque geometry by material and 8 m cell. Physics bodies
	# retain their original transforms and references. Doors/rigs stay dynamic.
	var groups = {}
	for n in get_children():
		if not n is MeshInstance3D or not n.visible or not n.mesh: continue
		if not n.material_override is StandardMaterial3D: continue
		if n.material_override.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		var key = str(n.material_override.get_rid())+str(Vector3i(floori(n.position.x/8),floori(n.position.y/FLOOR_H),floori(n.position.z/8)))
		if not groups.has(key): groups[key] = []
		groups[key].append(n)
	for group in groups.values():
		if group.size()<2: continue
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var center = group[0].position
		for n in group:
			var transform = n.transform
			transform.origin -= center
			for i in range(n.mesh.get_surface_count()): surface.append_from(n.mesh,i,transform)
		var instance = MeshInstance3D.new()
		instance.mesh = surface.commit()
		instance.material_override = group[0].material_override
		instance.position = center
		instance.visibility_range_end = 42
		instance.visibility_range_end_margin = 3
		add_child(instance)
		for n in group:
			# The mounted panel remains addressable by its interaction/validation.
			if mounted_panels.any(func(panel):return panel.node==n):
				n.visible = false
				continue
			for child in n.get_children(): child.reparent(self,true)
			remove_child(n)
			n.queue_free()
