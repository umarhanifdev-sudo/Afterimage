extends Node
var music: AudioStreamPlayer
var reflection: AudioStreamPlayer
var ambience: AudioStreamPlayer
var sounds = {}
var tension = 0.0
var enabled = false
var voices: Array[Node] = []
var step_variants = {}
var last_step_variant = -1
var dialogue_active = false
var scene = "title"
var danger_mix = 0.0
var dialogue_mix = 1.0
var music_gain = 0.0
var reflection_gain = 0.0
var ambience_gain = 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in ["pistol", "rifle", "shotgun", "step", "land", "slide", "reload", "empty", "hit", "ui", "heart", "memory", "lurker", "rusher", "stalker", "apex", "door_creak", "door_slam", "door_locked", "collapse", "switch", "charge", "shell", "pulse"]:
		sounds[id] = load("res://assets/audio/"+id+".wav")
	for surface in ["concrete","wood"]:
		step_variants[surface] = []
		for i in range(3): step_variants[surface].append(load("res://assets/audio/step_%s_%d.ogg"%[surface,i]))
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/unseen-horrors.ogg")
	music.stream.loop = true
	music.volume_db = -80
	add_child(music)
	reflection = AudioStreamPlayer.new()
	reflection.stream = load("res://assets/audio/what-remains.ogg")
	var custom_path = OS.get_executable_path().get_base_dir().path_join("Music/reflection.ogg")
	if not OS.has_feature("editor") and FileAccess.file_exists(custom_path):
		var custom = AudioStreamOggVorbis.load_from_file(custom_path)
		if custom: reflection.stream = custom
	reflection.stream.loop = true
	reflection.volume_db = -80
	add_child(reflection)
	ambience = AudioStreamPlayer.new()
	ambience.stream = load("res://assets/audio/building.wav")
	ambience.volume_db = -80
	add_child(ambience)

func start():
	if enabled:
		return
	enabled = true
	music.play()
	reflection.play()
	ambience.play()

func set_scene(value: String):
	scene = value

func _process(dt):
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(GameState.volume, 0.0001)))
	if is_instance_valid(music):
		var danger = smoothstep(.10,.70,tension) if scene=="play" else 0.0
		danger_mix = lerpf(danger_mix,danger,1-exp(-dt*(1.4 if danger>danger_mix else .4)))
		dialogue_mix = lerpf(dialogue_mix,.62 if dialogue_active else 1.0,1-exp(-dt*(5 if dialogue_active else 1.3)))
		var level = GameState.music_volume*dialogue_mix
		music_gain = lerpf(music_gain,level*danger_mix*.45,1-exp(-dt*1.4))
		reflection_gain = lerpf(reflection_gain,level*(1-danger_mix)*(.55 if scene in ["title","ending","remembrance"] else .30),1-exp(-dt*1.4))
		music.volume_db = linear_to_db(maxf(music_gain,.0001))
		reflection.volume_db = linear_to_db(maxf(reflection_gain,.0001))
		music.stream_paused = get_tree().paused
		reflection.stream_paused = get_tree().paused
		ambience_gain = lerpf(ambience_gain,0.0 if scene=="ending" else .065,1-exp(-dt))
		ambience.volume_db = linear_to_db(maxf(ambience_gain,.0001))
		ambience.stream_paused = get_tree().paused
		if enabled and not ambience.playing and not get_tree().paused:
			ambience.play()

func admit_voice(p: Node):
	voices = voices.filter(func(n):return is_instance_valid(n) and not n.is_queued_for_deletion())
	while voices.size()>=24: voices.pop_front().queue_free()
	voices.append(p)

func footstep(wood: bool, level: float):
	var index = (last_step_variant+randi_range(1,2))%3
	last_step_variant = index
	var p = AudioStreamPlayer.new()
	p.stream = step_variants["wood" if wood else "concrete"][index]
	p.volume_db = linear_to_db(maxf(level,.001))
	p.pitch_scale = randf_range(.96,1.04)
	add_child(p)
	admit_voice(p)
	p.finished.connect(p.queue_free)
	p.play()

func play(id: String, level: float = 1.0):
	if not sounds.has(id):
		return
	var p = AudioStreamPlayer.new()
	p.stream = sounds[id]
	p.volume_db = linear_to_db(maxf(level,0.001))
	p.pitch_scale = randf_range(0.95,1.05)
	add_child(p)
	admit_voice(p)
	p.finished.connect(p.queue_free)
	p.play()

func at(id: String, pos: Vector3, level: float = 0.7):
	if not sounds.has(id):
		return
	var p = AudioStreamPlayer3D.new()
	p.stream = sounds[id]
	p.volume_db = linear_to_db(maxf(level,0.001))
	p.unit_size = 6
	p.max_distance = 32
	add_child(p)
	admit_voice(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()

func shutdown():
	enabled = false
	for p in get_children():
		if p is AudioStreamPlayer or p is AudioStreamPlayer3D:
			p.stop()
			p.stream = null
	sounds.clear()
