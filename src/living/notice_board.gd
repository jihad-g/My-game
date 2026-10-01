class_name NoticeBoard
extends StaticBody3D
## The village notice board: interact to see the settlement's delivery requests.

var site: Node


func _ready() -> void:
	collision_layer = Layers.INTERACTABLE
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.8, 0.4)
	cs.shape = box
	cs.position.y = 0.9
	add_child(cs)


func get_interact_text() -> String:
	return "Read the notice board (requests)"


func interact(_player: Node) -> void:
	if Net.client_blocked("Village requests"):
		return
	Events.open_requests.emit(site)
