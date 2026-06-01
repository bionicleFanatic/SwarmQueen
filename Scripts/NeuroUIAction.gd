class_name NeuroUIAction
extends NeuroAction

var levelManager

func _init(level, actionWindow): #add the actionWindow if we're initializing this action as part of a wondow
	super(actionWindow)
	levelManager = level

func _get_name() -> String:
	return "ui"

func _get_description() -> String:
	return "Click a button"

func _get_schema() -> Dictionary:
	return JsonUtils.wrap_schema({
		"click":{
			"enum": ["Play Again", "Quit"]
		}
	})


func _validate_action(data: IncomingData, state: Dictionary) -> ExecutionResult:
	
	var choice := data.get_string("click")
	if(choice != "Play Again" and choice != "Quit"):
		return ExecutionResult.failure("Couldn't quite parse that click. It needs to be either \"Play Again\" or \"Quit\"")
	
	state["choice"] = choice
	return ExecutionResult.success()


func _execute_action(state: Dictionary) -> void:
	if(state["choice"] == "Play Again"):
		levelManager.PlayAgain()
	else:
		levelManager._on_quit_pressed()




