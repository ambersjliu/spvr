extends StaticBody3D


@export var target_index: int = -1  # Set by TargetController when instantiated
@export var highlight_color: Color = Color.YELLOW
@export var selected_color: Color = Color.RED
@export var inactive_color: Color = Color.GRAY

var _material: StandardMaterial3D
var _mesh_instance: MeshInstance3D
var _is_active: bool = false  # Whether this target is currently selectable
var _is_highlighted: bool = false

# Signals
signal target_selected(target_index: int)


func _ready() -> void:
	# Find the MeshInstance3D child
	_mesh_instance = get_node_or_null("MeshInstance3D")
	
	if _mesh_instance == null:
		push_error("Target requires a MeshInstance3D child node!")
		return
	
	# Create a unique material for this target
	_material = StandardMaterial3D.new()
	_material.albedo_color = inactive_color
	_mesh_instance.material_override = _material
	
	# Set up collision layer (targets should be on a specific layer)
	collision_layer = 2  # Layer 2 for targets
	collision_mask = 0


func set_active(active: bool) -> void:
	"""Set whether this target is currently selectable"""
	_is_active = active
	
	if _is_active:
		_material.albedo_color = highlight_color
		_material.emission_enabled = true
		_material.emission = highlight_color
		_material.emission_energy_multiplier = 2.0
	else:
		_material.albedo_color = inactive_color
		_material.emission_enabled = false


func set_highlighted(highlighted: bool) -> void:
	"""Set visual highlight state (for hover feedback)"""
	_is_highlighted = highlighted
	
	if not _is_active:
		return
	
	if _is_highlighted:
		_material.albedo_color = selected_color
		_material.emission = selected_color
		_material.emission_energy_multiplier = 4.0
	else:
		_material.albedo_color = highlight_color
		_material.emission = highlight_color
		_material.emission_energy_multiplier = 2.0


func handle_selection() -> void:
	"""Handle target selection (from raycast or VR pointer)"""
	if not _is_active:
		return
	
	print("Target ", target_index, " selected!")
	target_selected.emit(target_index)
	
	# Visual feedback - flash briefly
	_flash_selection()


func _flash_selection() -> void:
	"""Brief visual feedback on selection"""
	_material.albedo_color = Color.WHITE
	_material.emission = Color.WHITE
	_material.emission_energy_multiplier = 6.0
	
	# Reset after short delay
	await get_tree().create_timer(0.1).timeout
	
	if _is_active:
		set_active(true)


# VR XRTools Pointer Event Handler
func pointer_event(event) -> void:  # Type is XRToolsPointerEvent in VR
	"""Handle XRTools pointer events (for VR)"""
	# Check if XRToolsPointerEvent exists (we're in VR mode)
	# If not, this will be called with a generic event
	
	# For type checking in VR
	if event.has("event_type"):
		match event.event_type:
			0:  # XRToolsPointerEvent.Type.ENTERED
				set_highlighted(true)
			1:  # XRToolsPointerEvent.Type.EXITED
				set_highlighted(false)
			2:  # XRToolsPointerEvent.Type.PRESSED
				handle_selection()
			3:  # XRToolsPointerEvent.Type.RELEASED
				pass
			4:  # XRToolsPointerEvent.Type.MOVED
				pass

