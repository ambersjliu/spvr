

extends StaticBody3D

@export var dome_radius: float = 10.0
@export var show_debug_markers: bool = true

# Visual feedback
var _material: StandardMaterial3D
var _mesh_instance: MeshInstance3D

# Track last collision for debugging
var last_collision_point: Vector3 = Vector3.ZERO
var last_spherical_coords: Dictionary = {}

# Marker tracking
var current_marker: MeshInstance3D = null

signal dome_clicked(collision_point: Vector3, spherical_coords: Dictionary)


func _ready() -> void:
	# Find the MeshInstance3D child (if any)
	_mesh_instance = get_node_or_null("MeshInstance3D")
	
	if _mesh_instance and show_debug_markers:
		# Make dome semi-transparent for better visibility
		_material = StandardMaterial3D.new()
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_color = Color(0.5, 0.5, 1.0, 0.15)
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh_instance.material_override = _material
	
	# Set collision layers
	collision_layer = 4  # Layer 3 for dome
	collision_mask = 0
	
	print("DomeCollider ready with radius: ", dome_radius)


# XRTools Pointer Event Handler
func pointer_event(event) -> void:
	"""Handle XRTools pointer events"""
	# Check if this is a valid XRToolsPointerEvent
	if not event.has("event_type"):
		return
	
	# We only care about PRESSED events (trigger pull)
	if event.event_type != 2:  # 2 = XRToolsPointerEvent.Type.PRESSED
		return
	
	# Get collision point from event
	var collision_point: Vector3 = event.target_position if event.has("target_position") else Vector3.ZERO
	
	if collision_point == Vector3.ZERO:
		push_warning("No collision point in pointer event!")
		return
	
	# Process the collision
	_handle_dome_click(collision_point)


func _handle_dome_click(collision_point: Vector3) -> void:
	"""Process a click/press on the dome"""
	last_collision_point = collision_point
	
	# Convert to spherical coordinates
	var spherical_coords = global_to_spherical(collision_point)
	last_spherical_coords = spherical_coords
	
	print("Dome clicked at: ", collision_point)
	print("Spherical coords: ", spherical_coords)
	
	# Place visual marker
	if show_debug_markers:
		_place_marker(collision_point)
	
	# Emit signal for TrialController to handle
	dome_clicked.emit(collision_point, spherical_coords)


func global_to_spherical(global_point: Vector3) -> Dictionary:
	"""
	Convert global collision point to spherical coordinates
	Returns azimuth and elevation in both radians and degrees
	"""
	# Get point relative to dome center
	var local_point = global_point - global_position
	
	# Calculate radius (should be approximately dome_radius, but may vary slightly)
	var radius = local_point.length()
	
	# Normalize to unit sphere for angle calculations
	var normalized = local_point.normalized()
	
	# Calculate azimuth (horizontal angle around Y axis)
	# atan2(x, z) gives angle from forward (-Z) direction
	var azimuth = atan2(normalized.x, normalized.z)
	
	# Calculate elevation (vertical angle from horizontal plane)
	# asin(y) gives angle from XZ plane
	var elevation = asin(normalized.y)
	
	# Alternative: calculate polar angle from top (if you prefer this)
	var polar_angle = acos(normalized.y)  # Angle from +Y axis (0 at top, PI at bottom)
	
	return {
		"global_position": global_point,
		"local_position": local_point,
		"radius": radius,
		"azimuth_rad": azimuth,
		"azimuth_deg": rad_to_deg(azimuth),
		"elevation_rad": elevation,
		"elevation_deg": rad_to_deg(elevation),
		"polar_angle_rad": polar_angle,
		"polar_angle_deg": rad_to_deg(polar_angle),
		"normalized_direction": normalized
	}


func spherical_to_global(azimuth_rad: float, elevation_rad: float, radius: float = -1.0) -> Vector3:
	"""
	Convert spherical coordinates back to global position
	Useful for placing markers at specific angles
	"""
	if radius < 0:
		radius = dome_radius
	
	# Convert from azimuth/elevation to Cartesian
	var cos_elevation = cos(elevation_rad)
	var x = radius * cos_elevation * sin(azimuth_rad)
	var y = radius * sin(elevation_rad)
	var z = radius * cos_elevation * cos(azimuth_rad)
	
	return global_position + Vector3(x, y, z)


func _place_marker(position: Vector3, color: Color = Color.YELLOW) -> void:
	"""Place a visual marker at the clicked position"""
	# Remove previous marker if it exists
	if current_marker:
		current_marker.queue_free()
	
	# Create new marker
	current_marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	current_marker.mesh = sphere
	
	# Create glowing material
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	current_marker.set_surface_override_material(0, material)
	
	# Position marker
	add_child(current_marker)
	current_marker.global_position = position


func clear_marker() -> void:
	"""Remove the current marker"""
	if current_marker:
		current_marker.queue_free()
		current_marker = null


func validate_spherical_conversion() -> void:
	"""Debug function to test spherical coordinate conversion"""
	print("=== Testing Spherical Coordinate Conversion ===")
	
	# Test known positions
	var test_positions = [
		{"name": "Forward", "pos": global_position + Vector3(0, 0, -dome_radius)},
		{"name": "Right", "pos": global_position + Vector3(dome_radius, 0, 0)},
		{"name": "Up", "pos": global_position + Vector3(0, dome_radius, 0)},
		{"name": "45deg Up Forward", "pos": global_position + Vector3(0, dome_radius/sqrt(2), -dome_radius/sqrt(2))}
	]
	
	for test in test_positions:
		var coords = global_to_spherical(test.pos)
		print(test.name, ": ", coords)
		
		# Test reverse conversion
		var reconstructed = spherical_to_global(coords.azimuth_rad, coords.elevation_rad)
		var error = (reconstructed - test.pos).length()
		print("  Reconstruction error: ", error)
		print()


# Desktop raycast support (for testing without VR)
func handle_raycast_hit(collision_point: Vector3) -> void:
	"""Handle clicks from desktop raycast (for testing)"""
	_handle_dome_click(collision_point)