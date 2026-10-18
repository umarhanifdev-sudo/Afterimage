class_name MiloVoice
extends Node
var cooldown = 0.0
var refusal = 0.0
var reason = "LISTENING"

func _process(dt):
	cooldown = maxf(0.0, cooldown-dt)
	refusal = maxf(0.0, refusal-dt)
	if refusal <= 0:
		reason = "HIS CHOICE" if GameState.chapter == 3 else ("WATCHING THEIR HANDS" if GameState.lowered else "LISTENING")

func permits(target) -> bool:
	var line = ""
	if GameState.chapter == 3:
		line = "I remember what happened. I don't need to do it again."
		reason = "HIS CHOICE"
	elif is_instance_valid(target) and target.alive:
		if target.surrendered:
			line = "Their hands are up. I'm not firing."
			reason = "HANDS RAISED"
		elif target.kind != 0 and (GameState.chapter >= 2 or (GameState.chapter >= 1 and target.revealed)):
			line = "Look at them. They're trying to get out, too."
			reason = "NOT A THREAT"
		else:
			reason = "DEFENDING HIMSELF"
	if line.is_empty():
		return true
	refusal = 1.3
	if cooldown <= 0:
		GameState.say("MILO", line,{"priority":0,"ttl":3.5,"key":"refusal_"+reason})
		cooldown = 5.0
	return false
