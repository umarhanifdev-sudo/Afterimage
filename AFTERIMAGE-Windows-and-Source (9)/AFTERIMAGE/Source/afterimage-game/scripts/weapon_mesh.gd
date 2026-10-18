class_name ServiceWeapon
extends Node3D
var steel: StandardMaterial3D
var grip: StandardMaterial3D
var worn: StandardMaterial3D
var wood: StandardMaterial3D
var moving_part: Node3D
var moving_rest = Vector3.ZERO
var kind = 0
static var rounded_cache = {}

func mat(color: Color, metallic: float, roughness: float):
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	m.emission_enabled = true
	m.emission = color*.055
	var noise = FastNoiseLite.new()
	noise.frequency = .09
	noise.fractal_octaves = 3
	var wear = NoiseTexture2D.new()
	wear.width = 128
	wear.height = 128
	wear.noise = noise
	m.roughness_texture = wear
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(9,9,9)

	return m
func build(weapon_kind: int):
	kind = weapon_kind
	steel = mat(Color(.19,.21,.205),.45,.48)
	grip = mat(Color(.045,.044,.039),.05,.85)
	worn = mat(Color(.30,.31,.28),.75,.38)
	wood = mat(Color(.16,.095,.045),.0,.75)
	if kind==0:
		moving_part = block(Vector3(0,.025,-.16),Vector3(.105,.115,.29),steel)
		block(Vector3(0,-.044,-.14),Vector3(.088,.036,.31),grip)
		var handle = block(Vector3(0,-.15,-.055),Vector3(.085,.19,.095),grip)
		handle.rotation.x = -.18
		block(Vector3(0,-.247,-.035),Vector3(.093,.021,.10),steel)
		barrel(Vector3(0,.024,-.32),.036,.08,steel)
		barrel(Vector3(0,.024,-.365),.025,.006,grip)
		block(Vector3(0,.094,-.286),Vector3(.017,.025,.025),worn)
		for x in [-.038,.038]: block(Vector3(x,.092,-.035),Vector3(.02,.028,.035),steel)
		block(Vector3(.055,.033,-.12),Vector3(.004,.04,.06),grip)
		for i in range(6): block(Vector3(.054,.018,-.04-i*.012),Vector3(.004,.076,.004),worn)
		block(Vector3(0,-.085,-.16),Vector3(.014,.07,.02),steel)
		block(Vector3(0,-.125,-.17),Vector3(.06,.013,.10),steel)
		block(Vector3(0,-.088,-.215),Vector3(.06,.08,.012),steel)
	else:
		var shotgun = kind==2
		block(Vector3(0,-.005,-.13),Vector3(.105,.13,.28),steel)
		block(Vector3(0,-.055,.1),Vector3(.095,.17,.30),wood if shotgun else grip).rotation.x=-.06
		block(Vector3(0,-.085,.26),Vector3(.11,.20,.035),grip)
		barrel(Vector3(0,.026,-.48),.034 if shotgun else .023,.48,steel)
		barrel(Vector3(0,.026,-.726),.023 if shotgun else .016,.006,grip)
		barrel(Vector3(0,-.048,-.48),.029,.30,steel)
		block(Vector3(0,-.055,-.39),Vector3(.11,.085,.21),wood if shotgun else grip)
		for i in range(8): block(Vector3(0,-.055,-.31-i*.022),Vector3(.116,.092,.007),grip)
		block(Vector3(0,-.14,-.01),Vector3(.072,.17,.075),wood if shotgun else grip).rotation.x=-.2
		if not shotgun:
			var magazine = block(Vector3(0,-.17,-.15),Vector3(.065,.23,.10),steel)
			magazine.rotation.x=-.12
			moving_part = magazine
			block(Vector3(0,.08,-.16),Vector3(.058,.035,.21),steel)
			for i in range(8): block(Vector3(0,.104,-.06-i*.024),Vector3(.065,.014,.009),worn)
		block(Vector3(0,.079,-.64),Vector3(.015,.07,.027),steel)
		block(Vector3(.061,.02,-.06),Vector3(.015,.04,.10),worn)
		block(Vector3(0,-.10,-.08),Vector3(.012,.055,.018),steel)
	if moving_part: moving_rest = moving_part.position

static func palm_frame(across: Vector3, distal: Vector3) -> Basis:
	distal = distal.normalized()
	across = across.slide(distal).normalized()
	return Basis(across,distal.cross(across).normalized(),distal)

func grip_transform(side: String) -> Transform3D:
	var pos = Vector3(.052,-.15,-.055) if kind==0 else Vector3(.043,-.14,-.01)
	var basis = palm_frame(Vector3.UP,Vector3(0,.15,-1))
	if side=="L":
		pos = Vector3(-.025,-.116,-.35)
		basis = palm_frame(Vector3.BACK,Vector3.RIGHT)
	return global_transform*Transform3D(basis,pos)

func add_mesh(mesh: Mesh, pos: Vector3, material: Material):
	var n=MeshInstance3D.new()
	n.mesh=mesh
	n.material_override=material
	n.position=pos
	n.layers=2
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	return n
func block(pos: Vector3,size: Vector3,material: Material):
	var mesh=rounded_box(size,minf(.008,minf(size.x,minf(size.y,size.z))*.22))
	return add_mesh(mesh,pos,material)
func barrel(pos: Vector3,radius: float,length: float,material: Material):
	var mesh=CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=length
	mesh.radial_segments=16
	var n=add_mesh(mesh,pos,material)
	n.rotation.x=PI/2
	return n

func animate_parts(progress: float, kick: float):
	if not is_instance_valid(moving_part): return
	moving_part.position = moving_rest
	if moving_rest.y<-.1:
		moving_part.position.y -= sin(progress*PI)*.20
	else:
		moving_part.position.z += minf(.035,kick*.014)

static func rounded_box(size: Vector3, radius: float = .008) -> ArrayMesh:
	var key = str(size)+str(radius)
	if rounded_cache.has(key): return rounded_cache[key]
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var half = size*.5
	var core = half-Vector3.ONE*radius
	var directions = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
	for normal in directions:
		var u = Vector3.UP.cross(normal).normalized() if absf(normal.y)<.9 else Vector3.RIGHT
		var v = normal.cross(u)
		var width = absf(u.dot(half))
		var height = absf(v.dot(half))
		var depth = absf(normal.dot(half))
		var xs = [-width,-width+radius,0.0,width-radius,width]
		var ys = [-height,-height+radius,0.0,height-radius,height]
		for x in range(4):
			for y in range(4):
				for corner in [Vector2i(x,y),Vector2i(x,y+1),Vector2i(x+1,y+1),Vector2i(x,y),Vector2i(x+1,y+1),Vector2i(x+1,y)]:
					var point = normal*depth+u*xs[corner.x]+v*ys[corner.y]
					var nearest = point.clamp(-core,core)
					var n = (point-nearest).normalized()
					vertices.append(nearest+n*radius)
					normals.append(n)
					uvs.append(Vector2(xs[corner.x]/size.length(),ys[corner.y]/size.length()))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	rounded_cache[key] = mesh
	return mesh
