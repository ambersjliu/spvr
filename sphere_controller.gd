extends Node3D
# SphereController - Manages the 360-degree viewing environment
# Handles texture switching and TARGET (Point of Interest) visualization

@export var skybox_material: StandardMaterial3D
@export var target_scene: PackedScene  # Assign your TARGET marker scene

var current_texture: Texture2D
var target_markers: Array[Node3D] = []

# TARGET Configuration


var target_transforms: Array[Transform3D] = []


func _ready() -> void:
	# Connect to GameManager signals
	#GameManager.scene_changed.connect(_on_scene_changed)
	
	# Generate TARGET positions
	_generate_target_positions()
	_create_target_markers()
	
	print("SphereController ready with ", target_markers.size(), " TARGET markers")


#func load_360_texture(texture_path: String) -> void:
	#"""Load and apply a new 360-degree texture to the skybox"""
	#var texture = load(texture_path) as Texture2D
	#if texture == null:
		#push_error("Failed to load texture: " + texture_path)
		#return
	#
	#current_texture = texture
	#
	## Apply to skybox material
	#if skybox_material:
		#skybox_material.albedo_texture = texture
		#print("Loaded 360 texture: ", texture_path)
	#else:
		#push_error("Skybox material not assigned!")


func highlight_target_pair(target_a_index: int, target_b_index: int) -> void:
	"""Highlight two TARGETs for comparison (high-res trials)"""
	# First, hide all TARGETs
	hide_all_targets()
	
	# Show and highlight the specified pair
	if target_a_index < target_markers.size():
		var target_a = target_markers[target_a_index]
		target_a.visible = true
		_set_target_highlight(target_a, true)
	
	if target_b_index < target_markers.size():
		var target_b = target_markers[target_b_index]
		target_b.visible = true
		_set_target_highlight(target_b, true)


func show_all_targets() -> void:
	"""Show all TARGET markers (for low-res free selection)"""
	for target in target_markers:
		target.visible = true
		_set_target_highlight(target, false)


func hide_all_targets() -> void:
	"""Hide all TARGET markers"""
	for target in target_markers:
		target.visible = false


func get_target_transform(index: int) -> Transform3D:
	"""Get the transform of a specific TARGET"""
	if index < target_transforms.size():
		return target_transforms[index]
	return Transform3D.IDENTITY


# Private methods

func _generate_target_positions() -> void:
	"""Generate transforms for all TARGET positions on the sphere"""
	target_transforms.clear()
	
	var radius = 5.0  # Distance from center
	
	# Horizontal TARGETs (eye level, 45-degree increments)
	for i in range(global.HORIZONTAL_TARGETS):
		var angle = i * (2.0 * PI / global.HORIZONTAL_TARGETS)
		var transform = Transform3D()
		transform.origin = Vector3(
			cos(angle) * radius,
			0.0,
			sin(angle) * radius
		)
		# Look at center
		transform = transform.looking_at(Vector3.ZERO, Vector3.UP)
		target_transforms.append(transform)
	
	# Angled upward TARGETs
	var up_elevation = deg_to_rad(45)  # 30 degrees up
	for i in range(global.ANGLED_UP_TARGETS):
		var angle = i * (2.0 * PI / global.ANGLED_UP_TARGETS)
		var transform = Transform3D()
		transform.origin = Vector3(
			cos(angle) * sin(up_elevation) * radius,
			cos(up_elevation) * radius,
			sin(angle) * sin(up_elevation) * radius
		)
		transform = transform.looking_at(Vector3.ZERO, Vector3.UP)
		target_transforms.append(transform)
	
	# Angled downward TARGETs
	#var down_elevation = deg_to_rad(-30)  # 30 degrees down
	#for i in range(global.ANGLED_DOWN_TARGETS):
		#var angle = i * (2.0 * PI / global.ANGLED_DOWN_TARGETS)
		#var transform = Transform3D()
		#transform.origin = Vector3(
			#cos(angle) * cos(down_elevation) * radius,
			#sin(down_elevation) * radius,
			#sin(angle) * cos(down_elevation) * radius
		#)
		#transform = transform.looking_at(Vector3.ZERO, Vector3.UP)
		#target_transforms.append(transform)
	
	# Straight up
	var up_transform = Transform3D()
	up_transform.origin = Vector3(0, radius, 0)
	up_transform = up_transform.looking_at(Vector3.ZERO, Vector3.BACK)
	target_transforms.append(up_transform)
	
	# Straight down
	var down_transform = Transform3D()
	down_transform.origin = Vector3(0, -radius, 0)
	down_transform = down_transform.looking_at(Vector3.ZERO, Vector3.FORWARD)
	target_transforms.append(down_transform)
	
	print("Generated ", target_transforms.size(), " TARGET positions")


func _create_target_markers() -> void:
	"""Instantiate visual markers for each TARGET"""
	if target_scene == null:
		push_warning("TARGET scene not assigned - creating default markers")
		_create_default_target_markers()
		return
	
	for i in range(target_transforms.size()):
		var target_marker = target_scene.instantiate()
		target_marker.transform = target_transforms[i]
		target_marker.visible = false
		add_child(target_marker)
		target_markers.append(target_marker)


func _create_default_target_markers() -> void:
	"""Create simple sphere markers if no TARGET scene is provided"""
	for i in range(target_transforms.size()):
		var target_marker = MeshInstance3D.new()
		target_marker.mesh = SphereMesh.new()
		target_marker.mesh.radius = 0.1
		target_marker.mesh.height = 0.2
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.YELLOW
		material.emission_enabled = true
		material.emission = Color.YELLOW
		material.emission_energy_multiplier = 2.0
		target_marker.set_surface_override_material(0, material)
		
		target_marker.transform = target_transforms[i]
		target_marker.visible = false
		add_child(target_marker)
		target_markers.append(target_marker)


func _set_target_highlight(target: Node3D, highlighted: bool) -> void:
	"""Change TARGET appearance based on highlight state"""
	if target is MeshInstance3D:
		var material = target.get_surface_override_material(0) as StandardMaterial3D
		if material:
			if highlighted:
				material.albedo_color = Color.RED
				material.emission = Color.RED
				material.emission_energy_multiplier = 4.0
			else:
				material.albedo_color = Color.YELLOW
				material.emission = Color.YELLOW
				material.emission_energy_multiplier = 2.0


#func _on_scene_changed(scene_path: String) -> void:
	#"""Handle scene texture change from GameManager"""
	#load_360_texture(scene_path)
