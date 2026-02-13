extends Node3D

@export var target_scene: PackedScene
const horiz_targets = global.HORIZONTAL_TARGETS
const elevated_targets = global.VERTICAL_TARGETS

# from LLM generated code
var target_transforms: Array[Transform3D] = []
var target_markers: Array[Node3D] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_generate_target_transforms()
	_create_targets()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _generate_target_transforms():
	target_transforms.clear()
	var radius = 5.0
	for i in range(horiz_targets):
		var angle = i * 2.0 * PI / horiz_targets
		# x, z make horizontal plane
		var transform = Transform3D()
		transform.origin = Vector3(radius * cos(angle), 0.708, radius * sin(angle))
		transform = transform.looking_at(Vector3.ZERO, Vector3.UP)
		target_transforms.append(transform)
		
	# create elevated targets at maybe 45 degs up
	var up_angle = deg_to_rad(45)
		
		
	# Compute new angles based on angles from before	
	#for j in range(horiz_targets):
		#var angle = (j + 0.5) * 2.0 * PI / horiz_targets
		#var transform = Transform3D()
		#transform.origin = Vector3(radius * cos(angle) * sin(up_angle), 
									#radius * cos(up_angle),
									#radius * sin(angle) * sin(up_angle), )
		#transform = transform.looking_at(Vector3.ZERO, Vector3.UP)
		#target_transforms.append(transform)
	
	for i in range(elevated_targets):
		var angle = i * 2.0 * PI / elevated_targets + deg_to_rad(12)
		# x, z make horizontal plane
		var transform = Transform3D()
		transform.origin = Vector3(radius * cos(angle) * sin(up_angle), 
									radius * cos(up_angle),
									radius * sin(angle) * sin(up_angle), )
		transform = transform.looking_at(Vector3.ZERO, Vector3.UP)
		target_transforms.append(transform)
	
	var straight_up = Transform3D()
	straight_up.origin = Vector3(0, radius, 0)
	#straight_up = straight_up.looking_at(Vector3.ZERO, Vector3.BACK)
	target_transforms.append(straight_up)
	
	var straight_down = Transform3D()
	straight_down.origin = Vector3(0, -radius, 0)
	#straight_up = straight_up.looking_at(Vector3.ZERO, Vector3.BACK)
	target_transforms.append(straight_down)
	
func _create_targets():
	for i in range(target_transforms.size()):
		var target: Node3D = target_scene.instantiate()
		target.transform = target_transforms[i]
		target.visible = true
		add_child(target)
		target_markers.append(target)

func _hide_targets():
	for i in range(target_markers.size()):
		target_markers[i].visible = false

func _show_target_pair(index_1: int, index_2: int):
	target_markers[index_1].visible = true
	target_markers[index_2].visible = true
	
func _hide_target_pair(index_1: int, index_2: int):
	target_markers[index_1].visible = false
	target_markers[index_2].visible = false
		
