class_name AfterimageHUD
extends Control
const INK = Color(0.024,0.029,0.045)
const PAPER = Color(0.91,0.87,0.76)
const RED = Color(0.64,0.16,0.12)
const MUTED = Color(0.55,0.59,0.62)
var game
var mode = "title"
var previous_mode = "title"
var buttons: Array[Dictionary] = []
var selected = 0
var mouse = Vector2(-100,-100)
var heading: Font = preload("res://assets/fonts/BebasNeue-Regular.ttf")
var body: Font = preload("res://assets/fonts/BarlowSemiCondensed-Medium.ttf")
var silhouette: Texture2D = preload("res://assets/shadows-v2/forgotten-soldier.png")
var dialogue_queue: Array = []
var speaker = ""
var line = ""
var dialogue_time = 0.0
var dialogue_duration = 0.0
var dialogue_elapsed = 0.0
var dialogue_gap = 0.0
var dialogue_clock = 0.0
var dialogue_key = ""
var recent_dialogue = {}
var subtitle_style: StyleBoxFlat
var toast_text = ""
var toast_time = 0.0
var chapter_time = 0.0
var fade = 0.0
var clock = 0.0
var ending = "acceptance"
var letterbox = 0.0
var ui_scale = 1.0
var offset = Vector2.ZERO

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.dialogue_requested.connect(queue_dialogue)
	GameState.toast_requested.connect(func(text): toast_text=text; toast_time=3.6)
	subtitle_style = StyleBoxFlat.new()
	subtitle_style.bg_color = Color(.015,.018,.02,.9)
	subtitle_style.corner_radius_top_left = 3
	subtitle_style.corner_radius_top_right = 3
	subtitle_style.corner_radius_bottom_left = 3
	subtitle_style.corner_radius_bottom_right = 3

func reading_duration(value: String) -> float:
	var words = value.split(" ",false).size()
	var pauses = value.count(".")+value.count("?")+value.count("!")+value.count(",")
	return clampf(1.3+words*.36+pauses*.18,3.5,15.0)*GameState.subtitle_duration

func queue_dialogue(who: String, value: String, options: Dictionary = {}):
	var key = str(options.get("key",who+":"+value))
	if value.is_empty() or (dialogue_time>0 and (key==dialogue_key or value==line)): return
	if dialogue_clock-float(recent_dialogue.get(key,-1000))<9: return
	for entry in dialogue_queue:
		if entry.key==key or entry.text==value: return
	var priority = int(options.get("priority",1))
	var item = {"speaker":who,"text":value,"key":key,"priority":priority,
		"expires":dialogue_clock+float(options.get("ttl",5.0 if priority==0 else 120.0)),
		"duration":maxf(reading_duration(value),float(options.get("duration",0)))}
	# Discard obsolete barks first; story lines keep their order and reading time.
	if dialogue_queue.size()>=8:
		var expendable = -1
		for i in range(dialogue_queue.size()):
			if dialogue_queue[i].priority==0: expendable=i; break
		if expendable>=0: dialogue_queue.remove_at(expendable)
		else: return
	if priority==0: dialogue_queue.append(item)
	else:
		var at = dialogue_queue.size()
		for i in range(dialogue_queue.size()):
			if dialogue_queue[i].priority==0: at=i; break
		dialogue_queue.insert(at,item)

func has_dialogue() -> bool:
	return dialogue_time>0 or not dialogue_queue.is_empty()

func update_dialogue(dt: float):
	dialogue_clock += dt
	dialogue_queue = dialogue_queue.filter(func(entry): return entry.expires>dialogue_clock)
	if dialogue_time>0:
		dialogue_time = maxf(0,dialogue_time-dt)
		dialogue_elapsed += dt
		if dialogue_time<=0: dialogue_gap = .32
		return
	dialogue_gap = maxf(0,dialogue_gap-dt)
	if dialogue_gap>0 or dialogue_queue.is_empty(): return
	var next = dialogue_queue.pop_front()
	speaker = next.speaker
	line = next.text
	dialogue_key = next.key
	dialogue_duration = next.duration
	dialogue_time = dialogue_duration
	dialogue_elapsed = 0
	recent_dialogue[dialogue_key] = dialogue_clock
	GameState.dialogue_history.append({"speaker":speaker,"text":line})
	if GameState.dialogue_history.size()>24: GameState.dialogue_history.pop_front()

func set_mode(value: String):
	mode = value
	selected = 0
	mouse = Vector2(-100,-100)
	queue_redraw()

func clear_dialogue():
	dialogue_queue.clear()
	dialogue_time = 0
	dialogue_elapsed = 0
	dialogue_gap = 0
	dialogue_key = ""
	recent_dialogue.clear()
	line = ""
	Sound.dialogue_active = false

func _process(dt):
	clock += dt
	if not get_tree().paused and mode=="play":
		toast_time = maxf(0,toast_time-dt)
		chapter_time = maxf(0,chapter_time-dt)
		if fade<.35: update_dialogue(dt)
	Sound.dialogue_active = mode=="play" and dialogue_time>0
	queue_redraw()

func _input(event):
	if mode == "play":
		return
	if event is InputEventMouseMotion:
		mouse = (event.position-offset)/ui_scale
		for i in range(buttons.size()):
			if buttons[i].rect.has_point(mouse):
				selected = i
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mouse = (event.position-offset)/ui_scale
		for item in buttons:
			if item.rect.has_point(mouse):
				activate(item.id)
				get_viewport().set_input_as_handled()
				break
	if event is InputEventKey and event.pressed and not event.echo and not buttons.is_empty():
		match event.physical_keycode:
			KEY_DOWN, KEY_S:
				selected = (selected+1)%buttons.size()
				Sound.play("ui",.17)
			KEY_UP, KEY_W:
				selected = posmod(selected-1,buttons.size())
				Sound.play("ui",.17)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				activate(buttons[selected].id)
				get_viewport().set_input_as_handled()

func activate(id: String):
	Sound.start()
	Sound.play("ui",.4)
	game.on_ui(id)

func text(value: String, pos: Vector2, size_px: int, color: Color = PAPER, large: bool = false):
	draw_string(heading if large else body,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func paragraph(value: String, pos: Vector2, width: float, size_px: int = 22, color: Color = PAPER, line_height: float = 29.0) -> float:
	var y = pos.y
	for paragraph in value.split("\n"):
		var row = ""
		for word in paragraph.split(" "):
			var candidate = word if row.is_empty() else row+" "+word
			if body.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x>width and not row.is_empty():
				text(row,Vector2(pos.x,y),size_px,color)
				y += line_height
				row = word
			else:
				row = candidate
		text(row,Vector2(pos.x,y),size_px,color)
		y += line_height
	return y

func polygon(points: Array, color: Color):
	draw_colored_polygon(PackedVector2Array(points),color)

func cut_panel(rect: Rect2, color: Color, slant: float = 18):
	var p = rect.position
	var s = rect.size
	polygon([p+Vector2(slant,0),p+Vector2(s.x,0),p+s-Vector2(slant,0),p+Vector2(0,s.y)],color)

func button(id: String, title: String, pos: Vector2, width: float = 350, hint: String = ""):
	var index = buttons.size()
	var rect = Rect2(pos,Vector2(width,49))
	buttons.append({"id":id,"rect":rect})
	var active = index == selected
	cut_panel(rect,PAPER if active else Color(.075,.085,.10),14)
	if active:
		polygon([pos+Vector2(-10,7),pos+Vector2(-3,7),pos+Vector2(-15,42),pos+Vector2(-22,42)],RED)
	text(title,pos+Vector2(24,34),29,INK if active else PAPER,true)
	if not hint.is_empty():
		text(hint,pos+Vector2(width-91,31),17,RED if active else MUTED)

func _draw():
	var screen = get_viewport_rect().size
	ui_scale = minf(screen.x/1280,screen.y/720)
	offset = (screen-Vector2(1280,720)*ui_scale)/2
	draw_set_transform(offset,0,Vector2.ONE*ui_scale)
	buttons.clear()
	if mode == "play":
		draw_game()
	else:
		draw_menu()
	if fade>0:
		draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)),Color(.035,.025,.035,fade))

func draw_menu():
	var dark = .45 if mode == "ending" else .76
	draw_rect(Rect2(0,0,1280,720),Color(INK,dark))
	polygon([Vector2(0,0),Vector2(740,0),Vector2(606,720),Vector2(0,720)],Color(INK,.97))
	polygon([Vector2(1054,0),Vector2(1137,0),Vector2(857,720),Vector2(828,720)],Color(RED,.75 if mode == "title" else .17))
	draw_line(Vector2(45,34),Vector2(1235,34),Color(PAPER,.24),1)
	text("AFTERIMAGE",Vector2(48,60),24,PAPER,true)
	text("THE LAST ROOM",Vector2(1113,60),20,MUTED,true)
	text("A SHORT PSYCHOLOGICAL FPS",Vector2(48,692),15,MUTED)
	text("W / S  SELECT     ENTER  CONFIRM     ESC  BACK",Vector2(858,692),16,MUTED)
	match mode:
		"title":
			draw_title()
		"pause":
			text("HOLD YOUR FIRE.",Vector2(80,181),69,PAPER,true)
			text("CHAPTER %02d  /  %s"%[GameState.chapter+1,GameState.TITLES[GameState.chapter]],Vector2(84,219),20,MUTED)
			button("resume","CONTINUE",Vector2(87,273))
			button("journal","MEMORY FRAGMENTS",Vector2(87,332))
			button("settings","SETTINGS",Vector2(87,391))
			button("controls","CONTROLS",Vector2(87,450))
			button("retry","RESTART THIS CHAPTER",Vector2(87,509))
			button("title","RETURN TO TITLE",Vector2(87,568))
		"controls":
			text("LEARN THE WEIGHT.",Vector2(80,155),61,PAPER,true)
			var controls = [["W A S D / ARROWS","Move"],["MOUSE / RIGHT CLICK","Look / aim down sights"],["LEFT CLICK / R","Give fire order / reload"],["SHIFT / SPACE","Sprint / jump"],["CTRL OR C","Crouch; press while sprinting to slide"],["Q / F","Lower or raise weapon / flashlight"],["E / TAB","Interact or hold to force / memory journal"],["ESC / F11","Pause / toggle fullscreen"]]
			var y = 211.0
			for row in controls:
				text(row[0],Vector2(86,y),24,PAPER,true)
				text(row[1],Vector2(367,y),21,PAPER)
				y += 42
			paragraph("Milo carries you. You give the orders. Hold the light on a silhouette to read its intent. Red light warns of an attack. Hold E at generators or jammed doors.",Vector2(792,222),355,23,PAPER,30)
			paragraph("Lowering the weapon takes time and space. Some soldiers will listen. Others will still fire.",Vector2(792,409),355,23,MUTED,30)
			button("back","BACK",Vector2(87,589))
		"settings":
			text("MAKE ROOM TO BREATHE.",Vector2(80,155),60,PAPER,true)
			button("volume","MASTER VOLUME",Vector2(87,224),480,"%d%%"%roundi(GameState.volume*100))
			button("music","MUSIC VOLUME",Vector2(87,283),480,"%d%%"%roundi(GameState.music_volume*100))
			button("sensitivity","MOUSE SENSITIVITY",Vector2(87,342),480,"%.1f"%(GameState.sensitivity*1000))
			button("motion","REDUCED MOTION",Vector2(87,401),480,"ON" if GameState.reduced_motion else "OFF")
			button("difficulty","STORY ASSIST",Vector2(87,460),480,"ON" if GameState.story_mode else "OFF")
			button("subtitle_time","SUBTITLE DURATION",Vector2(87,519),480,"LONG" if GameState.subtitle_duration>1 else "NORMAL")
			button("subtitle_size","SUBTITLE SIZE",Vector2(87,578),480,"LARGE" if GameState.large_subtitles else "NORMAL")
			button("back","BACK",Vector2(771,578),377)
			paragraph("Click or press Enter to cycle.\n\nReduced motion softens head movement and keeps sprint FOV steady.\n\nStory assist halves incoming damage.\n\nLong subtitles give you 50% more reading time. Recent lines are in the memory journal.",Vector2(771,237),377,23,PAPER,31)
		"journal":
			text("WHAT REMAINS.",Vector2(80,158),66,PAPER,true)
			var entries = [
				["photo","01 / THE PHOTOGRAPH","Names on the back. Faces outside their uniforms."],
				["manifest","02 / THE EVACUATION LIST","The building sheltered people trying to escape."],
				["wristband","03 / THE WRISTBAND","Milo, 78. The room is a memory. The voice giving orders is his own."]]
			var y = 230.0
			for e in entries:
				var found = GameState.clues.has(e[0])
				text(e[1] if found else "? / AN ABSENT DETAIL",Vector2(86,y),33,PAPER if found else MUTED,true)
				paragraph(e[2] if found else "Look closely at the things you keep passing.",Vector2(86,y+36),595,22,PAPER if found else MUTED)
				y += 112
			paragraph("The past will not change.\nWhat you notice can.",Vector2(830,265),310,29,PAPER,39)
			text("WITNESSES HEARD  /  %02d"%GameState.witnessed.size(),Vector2(830,405),24,RED,true)
			button("back","BACK",Vector2(87,590))
			button("transcript","RECENT DIALOGUE",Vector2(830,590),330)
		"transcript":
			text("WORDS THAT REMAIN.",Vector2(80,155),61,PAPER,true)
			var recent = GameState.dialogue_history.slice(-3)
			var y = 215.0
			if recent.is_empty(): text("Listen. There is still time.",Vector2(87,y),24,MUTED)
			for entry in recent:
				text(entry.speaker,Vector2(87,y),17,Color(.75,.64,.45),true)
				y = paragraph(entry.text,Vector2(87,y+29),1060,23,PAPER,29)+28
			button("journal","MEMORY FRAGMENTS",Vector2(87,610))
		"credits":
			text("THE PEOPLE BEHIND THE ECHO.",Vector2(80,155),56,PAPER,true)
			paragraph("Premise and creative direction: your AFTERIMAGE concept.\n\nMusic: What Remains — original synthesized score. Unseen Horrors — Kevin MacLeod (incompetech.com), CC BY 4.0. Looped and mixed dynamically.\n\nParticle textures and optional source models: Kenney, CC0.\nFonts: Bebas Neue and Barlow Semi Condensed, SIL OFL.\n\nHuman mesh, rig and skin weights: MakeHuman, CC0. Furniture and materials: Poly Haven, CC0. Original interface, environment and synthesized effects. Powered by Godot 4.5.1.\n\nFull source links and licenses are included in CREDITS.md.",Vector2(87,218),950,22,PAPER,29)
			button("back","BACK",Vector2(87,590))
		"death":
			text("THE MEMORY BREAKS.",Vector2(80,190),68,PAPER,true)
			paragraph("You have not reached the end of this room.\nRetrying keeps this chapter and the fragments you found.",Vector2(87,255),530,25,PAPER,33)
			button("retry","TRY AGAIN",Vector2(87,391))
			button("settings","SETTINGS",Vector2(87,450))
			button("title","RETURN TO TITLE",Vector2(87,509))
		"choice":
			text("WHO GETS THE LAST WORD?",Vector2(80,171),61,PAPER,true)
			paragraph("MILO  /  I told myself you were another man. An order I had to obey. But you were the explanation I kept choosing.",Vector2(87,248),581,28,PAPER,36)
			paragraph("The door opens onto what happened. It will not open onto a different past.",Vector2(87,389),575,23,MUTED,31)
			button("accept","LET HIM FINISH",Vector2(87,500),480)
			button("insist","INSIST IT WAS NECESSARY",Vector2(87,559),480)
		"ending":
			text("MILO / 78",Vector2(803,165),35,PAPER,true)
			text("HOSPICE, PRESENT DAY",Vector2(805,192),18,MUTED)
			text("THE LAST ROOM.",Vector2(80,172),73,PAPER,true)
			text("ACCEPTANCE" if ending == "acceptance" else "ANOTHER EXPLANATION",Vector2(87,215),27,RED,true)
			var ending_text = "I was afraid. I hurt people. Some were trying to hurt me. Some were only trying to leave. I have spent a lifetime making those sentences mean the same thing.\n\nThey don't."
			if ending != "acceptance":
				ending_text = "It was necessary.\n\nThe sentence still arrives before the faces. It keeps the room standing, even here, even now.\n\nMilo has heard it all his life. He does not have to believe it forever."
			paragraph(ending_text,Vector2(87,277),490,25,PAPER,33)
			button("reconsider","RETURN TO THE QUESTION",Vector2(87,550),400)
			button("title","TITLE",Vector2(87,609),400)

func draw_title():
	# Original cut-paper composition: angular typography against a single readable silhouette.
	polygon([Vector2(802,111),Vector2(1203,77),Vector2(1099,607),Vector2(685,566)],Color(.11,.13,.17,.74))
	draw_texture_rect(silhouette,Rect2(806,83,350,526),false,Color(.65,.68,.74,.95))
	text("A PSYCHOLOGICAL FIRST-PERSON SHOOTER",Vector2(87,116),18,MUTED)
	text("AFTER",Vector2(82,243),155,RED,true)
	text("AFTER",Vector2(76,238),155,PAPER,true)
	text("IMAGE",Vector2(82,370),155,RED,true)
	text("IMAGE",Vector2(76,365),155,PAPER,true)
	cut_panel(Rect2(87,386,304,35),RED)
	text("THE LAST ROOM",Vector2(107,413),28,INK,true)
	paragraph("The building is burning. Milo is carrying you.\nTell him what to do.",Vector2(91,458),510,23,PAPER,29)
	var has_save = GameState.has_save()
	button("continue" if has_save else "new","CONTINUE" if has_save else "ENTER THE BUILDING",Vector2(94,528),342)
	button("new" if has_save else "controls","NEW MEMORY" if has_save else "HOW TO PLAY",Vector2(94,587),342)
	button("settings","SETTINGS",Vector2(464,528),220)
	button("credits","CREDITS",Vector2(464,587),220)
	button("quit","EXIT TO DESKTOP",Vector2(714,587),320)
	text("FIRE / SHADOW / TIME",Vector2(886,525),27,PAPER,true)
	text("The room remembers your orders.",Vector2(886,553),19,MUTED)

func draw_game():
	var p = game.player
	if not is_instance_valid(p): return
	if not game.cinematic_active:
		text("%02d  /  %s"%[GameState.chapter+1,GameState.TITLES[GameState.chapter]],Vector2(35,43),21,Color(PAPER,.75),true)
		text("FLOOR %02d"%(p.building.floor_index(p.global_position)+1),Vector2(35,64),13,MUTED)
		var order = "FLOOR 04 / REACH THE EXIT" if GameState.power_on else "FLOOR 02 / RESTORE EXIT POWER"
		if GameState.chapter==3: order = "REMEMBER THE THREE DETAILS" if GameState.clues.size()<3 else "RETURN TO THE FIRE DOOR"
		var width = body.get_string_size(order,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		text(order,Vector2(1245-width,43),16,Color(PAPER,.7))
		var center = Vector2(640,360-p.kick_pitch*220)
		if GameState.lowered:
			draw_arc(center,4,0,TAU,20,Color(PAPER,.5),1,true)
		elif not p.ads:
			draw_circle(center,1.6,Color(PAPER,.7))
			if p.recoil>.2: draw_arc(center,5+p.recoil*3,0,TAU,24,Color(PAPER,.25),1,true)
		if p.charging>0: draw_rect(Rect2(560,485,160*p.charging,2),PAPER)
		if is_instance_valid(p.target) and p.target.alive:
			var target = p.target
			if not target.revealed and p.lamp.visible: draw_arc(center,19,-PI/2,-PI/2+TAU*clampf(target.observed,0,1),32,Color(PAPER,.45),1,true)
			var desc = target.description()
			var w = body.get_string_size(desc,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
			text(desc,Vector2(640-w/2,412),16,PAPER)
			if target.trust>0 and not target.surrendered:
				draw_rect(Rect2(585,428,110*minf(target.trust/(2.6 if target.kind==0 else 1.8),1),2),PAPER)
		if not p.interaction.is_empty():
			var prompt = "E  /  "+str(p.interaction.prompt)
			var w = body.get_string_size(prompt,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
			draw_style_box(subtitle_panel(),Rect2(620-w/2,449,w+40,35))
			text(prompt,Vector2(640-w/2,473),18,PAPER)
		text("MILO",Vector2(35,629),17,PAPER,true)
		text(game.milo.reason,Vector2(35,649),13,RED if game.milo.refusal>0 else MUTED)
		draw_rect(Rect2(35,660,125,2),Color(PAPER,.15))
		draw_rect(Rect2(35,660,GameState.health*1.25,2),RED if GameState.health<35 else PAPER)
		if p.stamina<99: draw_rect(Rect2(35,668,p.stamina*1.25,1),MUTED)
		text("LIGHT  %03d"%roundi(p.battery),Vector2(35,694),14,RED if p.battery<18 else MUTED)
		if GameState.chapter<3:
			text("%02d"%p.ammo,Vector2(1139,660),48,RED if p.ammo==0 else PAPER,true)
			text("/ %03d"%p.reserve,Vector2(1193,659),22,MUTED,true)
			text("RELOADING" if p.reload_time>0 else ("LOWERED" if GameState.lowered else p.weapon.name),Vector2(1139,684),14,MUTED)
			if p.reload_time>0: draw_rect(Rect2(1139,693,105*(1-p.reload_time/float(p.weapon.reload)),2),PAPER)
		else: text("NO MORE ORDERS",Vector2(1090,666),23,PAPER,true)
		if toast_time>0:
			var w = body.get_string_size(toast_text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
			draw_style_box(subtitle_panel(),Rect2(620-w/2,90,w+40,34))
			text(toast_text,Vector2(640-w/2,114),17,PAPER)
		if chapter_time>0:
			var alpha = minf(1,chapter_time)
			var title = GameState.TITLES[GameState.chapter]
			var w = heading.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,48).x
			text(title,Vector2(640-w/2,211),48,Color(PAPER,alpha),true)
		if p.damage_flash>0:
			draw_rect(Rect2(0,0,9,720),Color(RED,p.damage_flash))
			draw_rect(Rect2(1271,0,9,720),Color(RED,p.damage_flash))
	if letterbox>0:
		draw_rect(Rect2(0,0,1280,70*letterbox),Color.BLACK)
		draw_rect(Rect2(0,720-70*letterbox,1280,70*letterbox),Color.BLACK)
	if game.cinematic_active:
		text("SPACE / SKIP",Vector2(1147,692),13,MUTED)
		if game.cinematic_time>2.6 and game.cinematic_time<6.8 and GameState.chapter==0:
			var opacity = minf(1,minf(game.cinematic_time-2.6,6.8-game.cinematic_time))
			text("A F T E R I M A G E",Vector2(439,328),47,Color(PAPER,opacity),true)
			text("THE LAST ROOM",Vector2(574,358),17,Color(PAPER,opacity))
	if dialogue_time>0:
		var font_size = 26 if GameState.large_subtitles else 23
		var row_height = font_size+6
		var rows = subtitle_rows(line,720,font_size)
		var height = 43+rows.size()*row_height
		var top = 650-height
		var alpha = minf(1,minf(dialogue_elapsed/.16,dialogue_time/.28))
		draw_style_box(subtitle_panel(),Rect2(259,top,762,height))
		draw_rect(Rect2(259,top,3,height),Color(RED,.8))
		text(speaker,Vector2(281,top+22),14,Color(.78,.70,.52,alpha),true)
		for i in range(rows.size()): text(rows[i],Vector2(281,top+50+i*row_height),font_size,Color(PAPER,alpha))

func subtitle_rows(value: String, width: float, font_size: int) -> Array[String]:
	var result: Array[String] = []
	for part in value.split("\n"):
		var row = ""
		for word in part.split(" ",false):
			var candidate = word if row.is_empty() else row+" "+word
			if not row.is_empty() and body.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:
				result.append(row)
				row = word
			else: row = candidate
		result.append(row)
	return result

func subtitle_panel() -> StyleBoxFlat:
	return subtitle_style
