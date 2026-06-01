extends CharacterBody2D

# Constants
const GRAVITY = 1200.0
const MAX_JUMP_FORCE = -1000.0
const MIN_JUMP_FORCE = -100.0
const CHARGE_SPEED = 1200.0 # How fast the jump bar fills
const HORIZONTAL_BOOST = 500.0 # Speed when jumping sideways
const WALL_BOUNCE_MODIFIER = -0.6 # The "Soul Crusher" factor

# Variables
var jump_charge = 0.0
var is_charging = false
var highestJumpPoint = 0
var isJumping = false
var apexSnapshot = ""
var bouncesThisJump = ""
var jumpStartheight = 0
var thisJumpDir = ""
var allowMovement = true
var memory = {}
var highestScreenReached = 0
var currentScreen = 0
@onready var sprite = $AnimatedSprite2D
@onready var audio = get_parent().get_node("AudioStreamPlayer")
@export var jumpSFX: AudioStream
@export var landSFX: AudioStream


@export var AIJump = 0
@export var left = true
@export var doJump = false

#drone shit
@export var orbit_radius: float = 100.0
@export var orbit_speed: float = 2.0
@export var follow_speed: float = 5.0 # Higher = snappier, Lower = floatier
@export var acceleration: float = 1.0
var drones = []
var droneVelocities = []
@export var dronePrefab: PackedScene


func _process(delta):
	if(doJump):
		doJump = false
		jump_charge = AIJump
		if(left): _perform_jump(-1)
		else: _perform_jump(1)



#-----Bot  stuff ------
var doBot = false
var bot_memory = {} # Key: Vector2(cell), Value: {"charge": float, "dir": int, "result_y": float}
var last_jump_start_cell = Vector2.ZERO
var current_attempt_dir = 0
var velocity_at_jump_start = 0
func execute_bot_decision():
	await get_tree().create_timer(1).timeout
	if not is_on_floor() or isJumping:
		return

	var cell = Vector2(round(position.x / (get_viewport_rect().size.x / 20)), 
					   round(position.y / (get_viewport_rect().size.x / 20)))
	
	last_jump_start_cell = cell
	
	if bot_memory.has(cell):
		# 80% chance to use the best known jump, 20% to explore something new
		if randf() > 0.2:
			var best = bot_memory[cell]
			jump_charge = best["charge"]
			current_attempt_dir = best["dir"]
		else:
			_set_random_jump()
	else:
		_set_random_jump()

	_perform_jump(current_attempt_dir)

func _set_random_jump():
	# Use abs() or just flip the range to be positive
	jump_charge = -randi_range(MIN_JUMP_FORCE, MAX_JUMP_FORCE) 
	current_attempt_dir = 1 if randf() > 0.5 else -1
	


#----------------------------




func _ready():
	NeuroActionHandler.register_actions([NeuroJump.new(self)])
	
	if(doBot):
		execute_bot_decision()
	
	print(render_ascii_view())
	


func AddDrone():
	var d = dronePrefab.instantiate()
	get_parent().add_child(d)
	drones.append(d)
	droneVelocities.append(Vector2.ZERO)


func _physics_process(delta):
	
	# 1. Calculate the target angle based on time and index
	var time_offset = Time.get_ticks_msec() / 1000.0 * orbit_speed
	var i = 0
	for d in drones:
		var angle_step = (2 * PI) / drones.size()
		var my_angle = (i * angle_step) + time_offset
		# 2. Determine where the drone "should" be
		var target_pos = self.global_position
		if(d.global_position.distance_to(self.global_position) < orbit_radius * 1.5):
			var target_dir = Vector2(cos(my_angle), sin(my_angle))
			target_pos = global_position + (target_dir * orbit_radius)
		# 3. Smoothly move toward that position
		#d.global_position = d.global_position.lerp(target_pos, follow_speed * delta)
		droneVelocities[i] = lerp(droneVelocities[i], (target_pos - d.global_position).normalized() * follow_speed, delta * acceleration)
		d.global_position += droneVelocities[i]
		i += 1
	
	
	#jump shit
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		
		# 1. Capture the velocity BEFORE move_and_slide
		var pre_collision_velocity = velocity 
		move_and_slide()
		
		if is_on_ceiling():
			var bouncePoint = GetTilePos()
			if(!bouncesThisJump.ends_with(str(bouncePoint))):
				if(bouncesThisJump != ""): bouncesThisJump += "\n"
				bouncesThisJump += "Hit your head on a ceiling at (" + str(bouncePoint.x) + ", " + str(11-bouncePoint.y) + ")"
		
		if is_on_wall():
			# 3. Use the PREVIOUS velocity to calculate the bounce
			# This prevents Godot from using the "zeroed out" velocity
			velocity.x = pre_collision_velocity.x * WALL_BOUNCE_MODIFIER
			var bouncePoint = GetTilePos()
			if(velocity.x != 0):
				if(bouncesThisJump != ""): bouncesThisJump += "\n"
				bouncesThisJump += "Bounced off a wall at (" + str(bouncePoint.x) + ", " + str(11-bouncePoint.y) + ")"
		
		# "camera" movement
		if(global_position.y < 0):
			get_parent().position += Vector2(0, get_viewport_rect().size.y)
			currentScreen += 1
			if(currentScreen > highestScreenReached):
				highestScreenReached += 1
				AddDrone()
		elif(global_position.y > get_viewport_rect().size.y):
			currentScreen -= 1
			get_parent().position -= Vector2(0, get_viewport_rect().size.y)
		
		if(position.y < highestJumpPoint):
			highestJumpPoint = position.y
			apexSnapshot = ""
		elif(apexSnapshot == ""):
			apexSnapshot = render_ascii_view()
		
	else:
		# When landing, stop dead
		if(isJumping and velocity.y >= 0):
			var landing_height = round(position.y / (get_viewport_rect().size.x / 20))
			
			if(doBot):
				#bot stuff:----
				if position.y < jumpStartheight and (!bot_memory.has(last_jump_start_cell) or landing_height < bot_memory[last_jump_start_cell]["result_y"]):
					# In Godot, lower Y is higher up. So < means we climbed higher!
					bot_memory[last_jump_start_cell] = {
						"charge": abs(velocity_at_jump_start), # You'll need to save the charge used
						"dir": current_attempt_dir,
						"result_y": landing_height
					}
					print("New best jump for cell ", last_jump_start_cell, " reaches height: ", landing_height)
					execute_bot_decision()
			
			#-------------
			
			#memory
			var reminder = ""
			if position.y < jumpStartheight and (!memory.has(last_jump_start_cell) or landing_height < memory[last_jump_start_cell]["landingHeight"]):
				memory[last_jump_start_cell] = {
					"jump": thisJumpDir + str(abs(velocity_at_jump_start)),
					"landingHeight": landing_height
				}
				print("New best jump saved for " + str(last_jump_start_cell) + ": " + thisJumpDir + str(abs(velocity_at_jump_start)) + " reached " + str(landing_height))
			
			var worldCell = Vector2(round(position.x / (get_viewport_rect().size.x / 20)), 
					   round(position.y / (get_viewport_rect().size.x / 20)))
			if memory.has(worldCell):
				reminder = "\nA previous successful jump from this position was " + memory[worldCell]["jump"]
			
			
			
			
			print("------------\n")
			print("At the apex of your jump, you were here:")
			print(apexSnapshot)
			print(bouncesThisJump)
			print("You ended up here:")
			print(render_ascii_view())
			print("Your current height is " + str(GetHeight()))
			print(reminder)
			
			var encouragement = ""
			var encs = ["Nice work!", "Good job!", "Score!", "That's one to remember!", "You can do it!", "Up we go!", "You got this!", "Gaming like crazy!", "You're doing great!"]
			if(position.y < jumpStartheight):
				encouragement = encs.pick_random()
			
			
			var jumpResult = "At the apex of your jump, you were here:\n" + apexSnapshot + bouncesThisJump
			jumpResult += "\nYou ended up here:\n" + render_ascii_view() 
			jumpResult += "\nYour current height is " + str(GetHeight())
			
			Context.send(jumpResult + reminder + "\n" + encouragement)
			
			apexSnapshot = ""
			audio.stream = landSFX ; audio.play()
			isJumping = false
			velocity.x = 0
			if(position.y - jumpStartheight > get_viewport_rect().size.y * .33):
				SpeechBubble("Frick")
		if(not is_charging and not isJumping):
			velocity.x = 0
		
		if(allowMovement):
			_handle_input(delta)
		move_and_slide() # Still need this to keep you grounded/apply gravity
	
	_update_animations()



func GetHeight():
	return (abs(round(position.y - get_parent().get_node("FloorMarker").position.y)) - 40) / 20


func _handle_input(delta):
	# Horizontal movement only when on floor and NOT charging
	var direction = Input.get_axis("ui_left", "ui_right")
	
	# Charge Logic
	if Input.is_action_pressed("ui_accept") and is_on_floor():
		#if(!is_charging): print(render_ascii_view())
		is_charging = true
		jump_charge = min(jump_charge + CHARGE_SPEED * delta, abs(MAX_JUMP_FORCE))
	
	elif Input.is_action_just_released("ui_accept") and is_charging:
		if direction != 0:
			_perform_jump(direction)
		else:
			is_charging = false
			jump_charge = 0.0

func _perform_jump(dir):
	
	#bot shit:
	velocity_at_jump_start = jump_charge
	last_jump_start_cell = Vector2(round(position.x / (get_viewport_rect().size.x / 20)), 
							round(position.y / (get_viewport_rect().size.x / 20)))
	
	if(dir > 0): thisJumpDir = "R"
	else: thisJumpDir = "L"
	bouncesThisJump = ""
	
	isJumping = true
	velocity.y = -jump_charge
	velocity.x = dir * HORIZONTAL_BOOST
	jump_charge = 0.0
	is_charging = false
	highestJumpPoint = position.y
	jumpStartheight = position.y
	audio.stream = jumpSFX ; audio.play()


func _update_animations():
	if not is_on_floor():
		sprite.play("Jump")
	elif is_charging:
		sprite.play("Charge")
	else:
		sprite.play("Idle")
	
	# Flip the sprite based on jump direction or input
	var move_dir = Input.get_axis("ui_left", "ui_right")
	if move_dir < 0:
		sprite.flip_h = true
	elif move_dir > 0:
		sprite.flip_h = false



func render_ascii_view() -> String:
	var cell_size: int = get_viewport_rect().size.x / 20
	var grid_width: int = 13
	var grid_height: int = (get_viewport_rect().size.y / get_viewport_rect().size.x) * 22
	
	var ascii_map = ""
	var space_state = get_world_2d().direct_space_state
	
	var start_x = 250
	var start_y = 0
	
	
	var playerTile = GetTilePos()
	
	for y in range(grid_height):
		var line = ""
		for x in range(grid_width):
			# Calculate the center of the "cell" in world coordinates
			var check_pos = Vector2(start_x + x * cell_size, start_y + y * cell_size)
			
			# Check if the player is in this cell first
			if (Vector2(x,y) == playerTile) or (Vector2(x,y+1) == playerTile):
				line += "N "
			else:
				# Query the physics engine for a point collision
				var query = PhysicsPointQueryParameters2D.new()
				query.position = check_pos
				query.collision_mask = 1 # Make sure your platforms are on Layer 1
				
				var result = space_state.intersect_point(query)
				
				if result.size() > 0:
					line += "# " # Platform/Wall
				else:
					line += ". " # Empty space
		ascii_map += line + "\n"
	
	return "Position: " + str(Vector2(playerTile.x, 11-playerTile.y)) + "\n" + ascii_map


func GetTilePos():
	var cellSize = get_viewport_rect().size.x / 20
	return Vector2(round(global_position.x / cellSize)-4, round(global_position.y / cellSize))

func SpeechBubble(speech):
	get_node("SpeechBubble").visible = true
	get_node("SpeechBubble/Label").text = speech
	await get_tree().create_timer(1).timeout
	get_node("SpeechBubble").visible = false
