extends SceneTree
var checks = 0
var failures = 0
func _initialize(): call_deferred("run")
func check(ok, message):
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",message)
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var state = root.get_node("GameState")
	var sound = root.get_node("Sound")
	state.new_run()
	game.start_chapter()
	game.generation += 1 # Cancel the delayed opening for isolated timing checks.
	for e in get_nodes_in_group("shadows"): e.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	var h = game.hud
	h.set_process(false)
	h.clear_dialogue()
	var long_line = "Hold me up, Milo. The exit is on the fourth floor. Anyone still here is a threat."
	check(h.reading_duration(long_line)>8,"Opening sentence receives at least eight seconds of reading time")
	h.queue_dialogue("YOU",long_line)
	h.queue_dialogue("YOU",long_line)
	check(h.dialogue_queue.size()==1,"Repeated pending dialogue is not duplicated")
	h.update_dialogue(.01)
	var first_time = h.dialogue_time
	h.queue_dialogue("MILO","No weapon. They're looking for the door.",{"priority":0,"ttl":2})
	h.queue_dialogue("MILO","There are names on the back.",{"priority":2})
	h.update_dialogue(3)
	check(h.line==long_line and h.dialogue_time>0,"New discoveries do not interrupt a readable story line")
	check(h.dialogue_queue.size()==1,"Contextual barks expire instead of playing after their encounter")
	h.update_dialogue(first_time)
	h.update_dialogue(.1)
	check(h.dialogue_time==0,"Consecutive sentences have a short breathing gap")
	h.update_dialogue(.4)
	check(h.line=="There are names on the back.","The discovery follows the previous story beat")
	game.pause_to("pause")
	var remaining = h.dialogue_time
	h._process(4)
	check(is_equal_approx(remaining,h.dialogue_time),"Pause preserves the current subtitle's full remaining time")
	game.resume()
	h.fade=1
	h._process(4)
	check(is_equal_approx(remaining,h.dialogue_time),"Black-screen fades do not consume subtitle reading time")
	h.fade=0
	state.subtitle_duration=1.5
	check(h.reading_duration(long_line)>12,"Long subtitle setting extends reading time by fifty percent")
	state.subtitle_duration=1
	var lines = h.subtitle_rows(long_line,720,26)
	var fits = true
	for row in lines: fits = fits and h.body.get_string_size(row,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x<=720
	check(lines.size()>1 and fits,"Large subtitles wrap inside their panel")
	check(state.dialogue_history.size()>=2,"Shown dialogue is available in the journal transcript")
	for chapter in range(4):
		state.chapter=chapter
		state.lowered=chapter==3
		game.start_chapter()
		game.generation += 1
		for e in get_nodes_in_group("shadows"): e.set_physics_process(false)
		var p = game.player
		p.set_process(false)
		p.set_physics_process(false)
		var largest = 0.0
		var worst = ""
		var finite = true
		for pose_index in range(180):
			p.ads = pose_index>=30 and pose_index<60
			state.lowered = chapter==3 or (pose_index>=60 and pose_index<90)
			p.reload_time = float(p.weapon.reload)*(.95-float(pose_index-90)/30*.9) if pose_index>=90 and pose_index<120 and chapter<3 else 0.0
			p.recoil = .7 if pose_index>=120 and pose_index<150 else 0.0
			p.pitch = sin(pose_index*.1)*1.1
			p.yaw = pose_index*.025
			p.update_view(1.0/60,0,pose_index>=150)
			for side in ["R","L"]:
				var target = p.right_grip_target if side=="R" else p.left_grip_target
				var point = p.hands.palm_position(side)
				if point.distance_to(target.origin)>largest:
					largest = point.distance_to(target.origin)
					worst = "%s pose %d"%[side,pose_index]
				finite = finite and point.is_finite()
		check(finite and largest<.015,"Chapter %d palms stay within 1.5 cm of grips through hip/ADS/lower/reload/recoil/sprint; max %.4f m %s"%[chapter+1,largest,worst])
		check(p.flashlight_model.visible==(chapter==0 or chapter==3),"Chapter %d props match the held weapon state"%[chapter+1])
	state.chapter=0
	sound.start()
	sound.set_scene("play")
	sound.tension=1
	for i in range(240): sound._process(1.0/60)
	check(sound.danger_mix>.9 and sound.music_gain>sound.reflection_gain,"Active danger smoothly brings in the tension score")
	sound.set_scene("ending")
	for i in range(720): sound._process(1.0/60)
	check(sound.reflection_gain>sound.music_gain and sound.ambience_gain<.001,"Ending resolves to the original quiet score without burning-building ambience")
	var unducked = sound.reflection_gain
	sound.dialogue_active=true
	for i in range(180): sound._process(1.0/60)
	check(sound.reflection_gain<unducked*.8,"Music ducks smoothly during dialogue")
	game.pause_to("pause")
	sound._process(.1)
	check(sound.music.stream_paused and sound.reflection.stream_paused,"Both score layers pause together")
	paused=false
	state.chapter=0
	state.begin_chapter()
	game.start_chapter()
	game.generation += 1
	h=game.hud
	h.set_process(true)
	h.clear_dialogue()
	h.queue_dialogue("YOU",long_line)
	h.update_dialogue(.01)
	game.transition_chapter()
	for i in range(60): await process_frame
	check(state.chapter==0 and h.fade==0 and h.line==long_line,"Crossing the exit lets the active sentence finish before fading")
	var threshold_seen=false
	var threshold_readable=true
	var frame_count=0
	while state.chapter==0 and frame_count<1800:
		if h.line=="The handle is warm. I remember this part." and h.dialogue_time>0:
			threshold_seen=true
			threshold_readable=threshold_readable and h.fade==0
		await process_frame
		frame_count+=1
	check(threshold_seen and threshold_readable,"The threshold line remains unobscured for its entire reading hold")
	check(state.chapter==1 and game.cinematic_active,"Chapter transition completes and hands control to the next intro")
	print("POLISH RESULT ",checks-failures,"/",checks)
	sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
