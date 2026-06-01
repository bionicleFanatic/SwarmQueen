extends Node

@export var left = true
@export var charge = 0
@export var send = false

func _ready():
	AwaitSend()

func AwaitSend():
	while !send:
		await get_tree().process_frame
	send = false
	SendPOST()
	AwaitSend()


func SendPOST():
	# Best practice is to have a separate node for each request
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._http_request_completed)
	
#	var error = http_request.request("http://localhost:1337/")
#	if error != OK:
#		push_error("An error occurred in the HTTP request.")
	
	var dir = "R"
	if(left): dir = "L"
	
	var data = JSON.new().stringify({
		"command": "action",
		"data": {
			"id": str(Time.get_ticks_msec()),
			"name": "jump",
			"data": "{" +
					"\"jump\": \"" + dir + str(charge) + "\"}"
		}
	})
	
	var error = http_request.request("http://localhost:1337/", ['Content-Type: application/json'], HTTPClient.METHOD_POST, data)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

# Called when the HTTP request is completed.
func _http_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
