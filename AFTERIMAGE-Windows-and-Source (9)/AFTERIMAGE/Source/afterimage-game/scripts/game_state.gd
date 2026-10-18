extends Node

signal dialogue_requested(speaker: String, line: String, options: Dictionary)
signal toast_requested(line: String)
const SAVE_PATH = "user://afterimage_save.json"
const TITLES = ["OBEDIENCE", "DOUBT", "RESISTANCE", "REMEMBRANCE"]
const WEAPONS = [
	{"name":"SERVICE PISTOL", "mag":9, "reserve":72, "damage":34.0, "interval":0.24, "reload":1.35, "recoil":1.6, "auto":false, "pellets":1, "sound":"pistol", "model":"c"},
	{"name":"ASSAULT RIFLE", "mag":24, "reserve":144, "damage":27.0, "interval":0.115, "reload":1.8, "recoil":1.1, "auto":true, "pellets":1, "sound":"rifle", "model":"a"},
	{"name":"BREACH SHOTGUN", "mag":7, "reserve":56, "damage":18.0, "interval":0.48, "reload":2.2, "recoil":3.6, "auto":true, "pellets":7, "sound":"shotgun", "model":"g"},
	{"name":"EMPTY HANDS", "mag":0, "reserve":0, "damage":0.0, "interval":0.4, "reload":1.0, "recoil":0.0, "auto":false, "pellets":0, "sound":"empty", "model":""}
]
var started = false
var chapter = 0
var health = 100.0
var clues: Dictionary = {}
var witnessed: Dictionary = {}
var shots = 0
var kills = 0
var casualties = 0
var mercies = 0
var deaths = 0
var lowered = false
var power_on = false
var sensitivity = 0.0022
var volume = 0.72
var music_volume = 0.55
var reduced_motion = false
var story_mode = false
var subtitle_duration = 1.0
var large_subtitles = false
var dialogue_history: Array[Dictionary] = []
var saved: Dictionary = {}

func _ready():
	if FileAccess.file_exists(SAVE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Dictionary:
			saved = data
			var settings = data.get("settings", {})
			sensitivity = float(settings.get("sensitivity", sensitivity))
			volume = float(settings.get("volume", volume))
			music_volume = float(settings.get("music", music_volume))
			reduced_motion = bool(settings.get("reduced_motion", false))
			story_mode = bool(settings.get("story_mode", false))
			subtitle_duration = clampf(float(settings.get("subtitle_duration",1.0)),1.0,1.5)
			large_subtitles = bool(settings.get("large_subtitles",false))

func new_run():
	started = true
	chapter = 0
	clues.clear()
	witnessed.clear()
	dialogue_history.clear()
	shots = 0
	kills = 0
	casualties = 0
	mercies = 0
	deaths = 0
	begin_chapter()

func has_save() -> bool:
	return saved.has("chapter")

func resume_run():
	started = true
	chapter = clampi(int(saved.get("chapter", 0)), 0, 3)
	clues = saved.get("clues", {}).duplicate()
	witnessed = saved.get("witnessed", {}).duplicate()
	shots = int(saved.get("shots", 0))
	kills = int(saved.get("kills", 0))
	casualties = int(saved.get("casualties", 0))
	mercies = int(saved.get("mercies", 0))
	deaths = int(saved.get("deaths", 0))
	begin_chapter()

func begin_chapter():
	health = 100.0
	lowered = chapter == 3
	power_on = false
	save_checkpoint()

func save_checkpoint():
	saved = {"chapter":chapter, "clues":clues.duplicate(), "witnessed":witnessed.duplicate(), "shots":shots, "kills":kills, "casualties":casualties, "mercies":mercies, "deaths":deaths}
	save_settings()

func save_settings():
	saved["settings"] = {"sensitivity":sensitivity, "volume":volume, "music":music_volume, "reduced_motion":reduced_motion, "story_mode":story_mode,"subtitle_duration":subtitle_duration,"large_subtitles":large_subtitles}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(saved))

func say(who: String, line: String, options: Dictionary = {}):
	dialogue_requested.emit(who, line, options)

func toast(line: String):
	toast_requested.emit(line)

func note_witness(id: String):
	if not witnessed.has(id):
		witnessed[id] = true
		mercies += 1
		save_checkpoint()

func clue(id: String, line: String):
	clues[id] = true
	save_checkpoint()
	say("MILO", line,{"priority":2,"key":"clue_"+id})
	toast("FRAGMENT RECOVERED  /  TAB TO REMEMBER")

func weapon() -> Dictionary:
	return WEAPONS[chapter]
