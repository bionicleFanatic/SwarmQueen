class_name NeuroJump
extends NeuroAction


var chargeCatch = 0
var player = null


func _init(playerNode, actionWindow=null): #add the actionWindow if we're initializing this action as part of a wondow
	if(actionWindow != null):
		super(actionWindow)
	
	player = playerNode

func _get_name() -> String:
	return "jump"

func _get_description() -> String:
	return "Choose a direction & charge time."

func _get_schema() -> Dictionary:
	return JsonUtils.wrap_schema({
		"jump":{
			"type": "string"
		}
	})


func _validate_action(data: IncomingData, state: Dictionary) -> ExecutionResult:
	
	var jump := data.get_string("jump")
	print(jump)
	if(!jump.begins_with("L") and !jump.begins_with("R")):
		return ExecutionResult.failure("Oopsie, remember to choose a direction! (Put L or R in front of your charge time)")
	
	if(!player.is_on_floor()):
		return ExecutionResult.failure("The player was still mid-air, try again now.")
	
	var dir = -1
	if(jump.begins_with("R")):
		dir = 1
	
	var charge = int(jump.right(-1))
	
	if(charge == 0):
		chargeCatch += 1
		var disclaimer = ""
		if(chargeCatch > 3): 
			disclaimer = "(If you ARE trying to charge up, and still recieving this error, let me know! It might be my vibe code messing up)"
		return ExecutionResult.failure("Your jump has to be charge for at least 50 milliseconds!" + disclaimer)
	
	state["dir"] = dir
	state["charge"] = charge
	return ExecutionResult.success()
	chargeCatch = 0


func _execute_action(state: Dictionary) -> void:
	player.jump_charge = state["charge"]
	player._perform_jump(state["dir"])
	pass




