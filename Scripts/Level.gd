extends Node2D

@onready var timer = get_node("CanvasLayer/Timer")

var openingBlurb = """
You're playing Swarm Queen! Legally distinct Jump King!
Here's a snapshot of the screen:
# # # # . . . . . # # # # 
# . . . . . . . . . . . # 
# . . . . . . . . . . . # 
# . . . . . . . . . . . # 
# . . . # # # # # . . . # 
# . . . . . . . . . . . # 
# . . . . . . . . . . . # 
# # # # . . . . . # # # # 
# # # # . . N . . # # # # 
# # # # . . N . . # # # # 
# # # # # # # # # # # # # 
# # # # # # # # # # # # #

You're in the tiles marked N (for Neuro!)
When the game is ready for your inputs, choose a direction (L or R) and a charge time (between 50 and 1000 milliseconds).
Your charge changes the angle of the jump - You can hop along the ground with short ~50ms bursts, or absolutely send it with a flying 1000ms arc. 
Bouncing off a wall reverses your horizontal velocity. This can be exploited to reach otherwise impossible ledges!
Good luck! The clock is ticking!
"""

var timing = true
var sceneTime = 0.0
const SAVE_PATH = "user://SwarmQueenSave.cfg"
var high_score = 0
@export var victoryMusic: AudioStream


func _ready():
	Context.send(openingBlurb, true)
	LoadSaveData()

func save_high_score(new_score: int):
	Context.send("New high score!!!" + str(new_score) + "! Attagirl!")
	
	high_score = new_score
	var config = ConfigFile.new()
	config.set_value("Progression", "high_score", high_score)
	var error = config.save(SAVE_PATH)
	if error != OK:
		print("An error occurred while saving high score.")

func LoadSaveData():
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH)
	
	# If the file doesn't exist, just keep the default (0)
	if error == OK:
		high_score = config.get_value("Progression", "high_score", 0)
		
		var socketURL = config.get_value("Neuro", "WebsocketAddress", null)
		if(socketURL != null):
			OS.set_environment("NEURO_SDK_WS_URL", socketURL)
		else:
			var save = ConfigFile.new()
			config.set_value("Progression", "high_score", high_score)
			config.set_value("Neuro", "WebsocketAddress", "ws://localhost:8000")
			config.save(SAVE_PATH)


func _process(delta):
	sceneTime += delta
	if(timing):
		timer.text = str(round(304 - sceneTime))
		
		if(timer.text == "0"):
			timing = false
			NeuroActionHandler.unregister_actions([NeuroActionHandler.get_action("jump")])
			get_node("Neuro").allowMovement = false
			timing = false
			
			await get_tree().create_timer(2).timeout
			EndScreen()


func _on_win_body_entered(body):
	Context.send("Congratulations!!! You reached the top and became the Swarm Queen!")
	if (get_node("Neuro").position.y > -5550): return
	
	NeuroActionHandler.unregister_actions([NeuroActionHandler.get_action("jump")])
	get_node("Neuro").allowMovement = false
	timing = false
	
	var tween = get_tree().create_tween().set_parallel(true) ; tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "position", Vector2(0, 6000), 1)
	tween.tween_property(get_node("Music"), "volume_db", -80, 1)
	
	await tween.finished
	await get_tree().create_timer(1).timeout
	
	get_node("Music").stop()
	
	get_node("CelebrationR").emitting = true
	get_node("CelebrationL").emitting = true
	
	get_node("Music").stream = victoryMusic
	get_node("Music").volume_db = 6
	get_node("Music").play()
	
	await get_tree().create_timer(3).timeout
	EndScreen()


func EndScreen():
	var tween = get_tree().create_tween().set_parallel(true) ; tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(get_node("CanvasLayer/Pinkout"), "modulate", Color.WHITE, 1)
	tween.tween_property(get_node("CanvasLayer/Highscore"), "position", (get_viewport_rect().size / 2) - (get_node("CanvasLayer/Highscore").size / 2), 1)
	
	if(high_score <= 0 and -int(timer.text) < high_score):
		high_score = -int(timer.text)
		save_high_score(high_score)
	elif(get_node("Neuro").GetHeight() > high_score):
		high_score = get_node("Neuro").GetHeight()
		save_high_score(high_score)
	else:
		Context.send("You achieved a final height of " + str(get_node("Neuro").GetHeight()) + ". Keep at it, smartest cookie!")
	
	var displayScore = high_score
	if(displayScore < 0): displayScore = -displayScore + round(get_node("Neuro").GetHeight())
	
	get_node("CanvasLayer/Highscore/Label").text = "Final Height: " + str(round(get_node("Neuro").GetHeight())) + "\nTime Left: " + timer.text + "\nHighscore: " + str(displayScore)
	
	await get_tree().create_timer(5).timeout
	var actionWindow := ActionWindow.new(self)
	actionWindow.set_force(0, "Click a button:", "", true, ActionsForce.Priority.LOW)
	actionWindow.add_action(NeuroUIAction.new(self, actionWindow))
	actionWindow.register()



func PlayAgain():
	var tween = get_tree().create_tween() ; tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(get_node("CanvasLayer/Highscore"), "position", Vector2((get_viewport_rect().size.x/2) - (get_node("CanvasLayer/Highscore").size.x/2), get_viewport_rect().size.y), 1)
	await tween.finished
	get_tree().reload_current_scene()


func _on_quit_pressed():
	get_tree().quit()
