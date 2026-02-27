extends Control
# TrialController - Manages individual trial flow and UI
# Handles high-res (target selection) and low-res (free view selection) trials

@export var target_controller: Node3D
@export var camera: Camera3D
@export var dome_collider: Node3D  # DomeCollider for low-res free selection
@export var instruction_label: Label

# UI for low-res trials
@export var favorite_button: Button
@export var least_favorite_button: Button
@export var confirm_button: Button

# Mode for low-res selection
enum LowResMode {
	NONE,
	MARKING_FAVORITE,
	MARKING_LEAST_FAVORITE
}
var low_res_mode: LowResMode = LowResMode.NONE

var current_trial_data: Dictionary = {}
var trial_type: int  # GameManager.TrialType
var trial_start_time: int = 0

# For low-res trials
var selected_favorite: Dictionary = {}
var selected_least_favorite: Dictionary = {}
var favorite_marker: Node3D
var least_favorite_marker: Node3D


func _ready() -> void:
	# Connect to GameManager
	GameManager.trial_started.connect(_on_trial_started)
	
	# Connect to TargetController
	if target_controller and target_controller.has_signal("target_selected"):
		target_controller.target_selected.connect(_on_target_selected)
	
	# Connect to DomeCollider (for low-res free selection)
	if dome_collider and dome_collider.has_signal("dome_clicked"):
		dome_collider.dome_clicked.connect(_on_dome_clicked)
	
	# Connect low-res UI buttons
	if favorite_button:
		favorite_button.pressed.connect(_on_mark_favorite_pressed)
	if least_favorite_button:
		least_favorite_button.pressed.connect(_on_mark_least_favorite_pressed)
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)


func _on_trial_started(trial_data: Dictionary) -> void:
	"""Initialize a new trial based on trial data from GameManager"""
	current_trial_data = trial_data
	trial_type = trial_data["type"]
	trial_start_time = Time.get_ticks_msec()
	
	match trial_type:
		GameManager.TrialType.HIGH_RES:
			_setup_high_res_trial()
		GameManager.TrialType.LOW_RES:
			_setup_low_res_trial()


func _setup_high_res_trial() -> void:
	"""Set up a high-resolution pairwise comparison trial"""
	_set_ui_visibility(true, false)
	
	# Get target pair from trial data
	var target_pair = current_trial_data["target_pair"]
	var target_a_index = target_pair["target_a_index"]
	var target_b_index = target_pair["target_b_index"]
	
	# Show only the two targets for this comparison
	target_controller.show_target_pair(target_a_index, target_b_index)
	
	# Update instructions
	if instruction_label:
		instruction_label.text = "Look at each highlighted viewpoint.\nClick on the better view to select it."
	
	print("High-res trial: comparing targets ", target_a_index, " and ", target_b_index)


func _setup_low_res_trial() -> void:
	"""Set up a low-resolution free selection trial"""
	_set_ui_visibility(false, true)
	
	# Hide all targets for free exploration
	target_controller.hide_targets()
	
	# Reset selections
	selected_favorite = {}
	selected_least_favorite = {}
	low_res_mode = LowResMode.NONE
	_clear_selection_markers()
	_update_confirm_button()
	
	# Enable dome collider if using VR pointer method
	if dome_collider and dome_collider.has_method("clear_marker"):
		dome_collider.clear_marker()
	
	# Update instructions based on mode
	if instruction_label:
		if dome_collider:
			# VR mode with dome clicking
			instruction_label.text = """Freely explore the scene.

VR Mode:
- LEFT controller: Click to mark FAVORITE view
- RIGHT controller: Click to mark LEAST FAVORITE view
- Press B/Y to CONFIRM when both marked

Desktop Mode:
- Click buttons below, then shoot at the dome"""
		else:
			# Desktop mode with buttons only
			instruction_label.text = "Freely explore the scene.\nMark your favorite and least favorite views."
	
	# Reset button text
	if favorite_button:
		favorite_button.text = "Mark Favorite"
	if least_favorite_button:
		least_favorite_button.text = "Mark Least Favorite"
	
	print("Low-res trial started")


func _set_ui_visibility(show_high_res: bool, show_low_res: bool) -> void:
	"""Toggle UI elements based on trial type"""
	if favorite_button:
		favorite_button.visible = show_low_res
	if least_favorite_button:
		least_favorite_button.visible = show_low_res
	if confirm_button:
		confirm_button.visible = show_low_res


# ===== HIGH-RES TRIAL HANDLERS =====

func _on_target_selected(target_index: int) -> void:
	"""Handle target selection from TargetController"""
	if trial_type != GameManager.TrialType.HIGH_RES:
		return
	
	var target_pair = current_trial_data["target_pair"]
	var target_a_index = target_pair["target_a_index"]
	var target_b_index = target_pair["target_b_index"]
	
	# Determine which target was selected
	var choice: String
	if target_index == target_a_index:
		choice = "A"
	elif target_index == target_b_index:
		choice = "B"
	else:
		push_warning("Invalid target selected: ", target_index)
		return
	
	_record_high_res_choice(choice, target_index)


func _record_high_res_choice(choice: String, selected_index: int) -> void:
	"""Record the ranking choice and advance to next trial"""
	var target_pair = current_trial_data["target_pair"]
	var response_time = Time.get_ticks_msec() - trial_start_time
	
	var ranking_data = {
		"type": "high_res",
		"scene": current_trial_data["scene"],
		"target_a_index": target_pair["target_a_index"],
		"target_b_index": target_pair["target_b_index"],
		"choice": choice,
		"selected_index": selected_index,
		"response_time_ms": response_time
	}
	
	print("Recording high-res choice: ", choice, " (target ", selected_index, ")")
	
	GameManager.record_ranking(ranking_data)
	
	# Small delay before next trial for visual feedback
	await get_tree().create_timer(0.3).timeout
	GameManager.start_next_trial()


# ===== LOW-RES TRIAL HANDLERS =====

func _on_mark_favorite_pressed() -> void:
	"""Mark current view as favorite"""
	if dome_collider:
		# VR/Dome mode - set mode and wait for dome click
		low_res_mode = LowResMode.MARKING_FAVORITE
		if favorite_button:
			favorite_button.text = "Select anywhere on the upper half of visual field as your favourite"
		print("Waiting for dome click to mark favorite...")
	else:
		# Desktop mode - use camera direction directly
		if not camera:
			push_error("Camera not assigned!")
			return
		
		# Get current view direction
		selected_favorite = global.player.get_spherical_coordinates()
		selected_favorite["timestamp"] = Time.get_ticks_msec()
		
		# Create/update visual marker
		_place_selection_marker(selected_favorite, true)
		
		if favorite_button:
			favorite_button.text = "Favorite Marked ✓"
		
		_update_confirm_button()
		print("Favorite marked at: ", selected_favorite)


func _on_mark_least_favorite_pressed() -> void:
	"""Mark current view as least favorite"""
	if dome_collider:
		low_res_mode = LowResMode.MARKING_LEAST_FAVORITE
		if least_favorite_button:
			least_favorite_button.text = "Select anywhere on the upper half of visual field as your least favourite"
		print("Waiting for dome click to mark least favorite...")
	else:
		# Desktop mode - use camera direction directly
		if not camera:
			push_error("Camera not assigned!")
			return
		
		# Get current view direction
		selected_least_favorite = global.player.get_spherical_coordinates()
		selected_least_favorite["timestamp"] = Time.get_ticks_msec()
		
		# Create/update visual marker
		_place_selection_marker(selected_least_favorite, false)
		
		if least_favorite_button:
			least_favorite_button.text = "Least Favorite Marked ✓"
		
		_update_confirm_button()
		print("Least favorite marked at: ", selected_least_favorite)


func _place_selection_marker(coords: Dictionary, is_favorite: bool) -> void:
	"""Place a visual marker at the selected location"""
	var radius = 5.0  # Same as target sphere radius
	var direction: Vector3 = coords["direction"]
	var position = direction * radius
	
	# Create or update marker
	var marker = favorite_marker if is_favorite else least_favorite_marker
	
	if marker == null:
		# Create new marker
		marker = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		marker.mesh = sphere
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.GREEN if is_favorite else Color.RED
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 3.0
		marker.set_surface_override_material(0, material)
		
		target_controller.add_child(marker)
		
		if is_favorite:
			favorite_marker = marker
		else:
			least_favorite_marker = marker
	
	# Update marker position
	marker.global_position = camera.global_position + direction * radius
	marker.visible = true


func _clear_selection_markers() -> void:
	"""Remove visual markers from previous trial"""
	if favorite_marker:
		favorite_marker.queue_free()
		favorite_marker = null
	if least_favorite_marker:
		least_favorite_marker.queue_free()
		least_favorite_marker = null


func _update_confirm_button() -> void:
	"""Enable confirm button only when both selections are made"""
	if confirm_button:
		confirm_button.disabled = selected_favorite.is_empty() or selected_least_favorite.is_empty()


func _on_confirm_pressed() -> void:
	"""Submit low-res trial selections"""
	var ranking_data = {
		"type": "low_res",
		"scene": current_trial_data["scene"],
		"favorite": selected_favorite,
		"least_favorite": selected_least_favorite,
		"trial_duration_ms": Time.get_ticks_msec() - trial_start_time
	}
	
	print("Recording low-res selections")
	
	GameManager.record_ranking(ranking_data)
	GameManager.start_next_trial()


# ===== DOME COLLIDER HANDLERS (VR/Desktop) =====

func _on_dome_clicked(collision_point: Vector3, spherical_coords: Dictionary) -> void:
	"""Handle dome click from VR pointer or desktop raycast"""
	if trial_type != GameManager.TrialType.LOW_RES:
		return
	
	print("Dome clicked - mode: ", low_res_mode)
	
	# Determine what to mark based on current mode
	match low_res_mode:
		LowResMode.MARKING_FAVORITE:
			_mark_favorite_at_coords(spherical_coords, collision_point)
			low_res_mode = LowResMode.NONE
		LowResMode.MARKING_LEAST_FAVORITE:
			_mark_least_favorite_at_coords(spherical_coords, collision_point)
			low_res_mode = LowResMode.NONE
		LowResMode.NONE:
			# No mode active - button press required first
			push_warning("Dome clicked but no marking mode active. Press a button first!")


func _mark_favorite_at_coords(spherical_coords: Dictionary, collision_point: Vector3) -> void:
	"""Mark the favorite location using dome collision data"""
	selected_favorite = spherical_coords.duplicate(true)
	selected_favorite["timestamp"] = Time.get_ticks_msec()
	
	# Place visual marker
	_place_dome_marker(collision_point, Color.GREEN, true)
	
	if favorite_button:
		favorite_button.text = "Favorite Marked ✓"
	
	_update_confirm_button()
	print("Favorite marked at: ", spherical_coords)


func _mark_least_favorite_at_coords(spherical_coords: Dictionary, collision_point: Vector3) -> void:
	"""Mark the least favorite location using dome collision data"""
	selected_least_favorite = spherical_coords.duplicate(true)
	selected_least_favorite["timestamp"] = Time.get_ticks_msec()
	
	# Place visual marker
	_place_dome_marker(collision_point, Color.RED, false)
	
	if least_favorite_button:
		least_favorite_button.text = "Least Favorite Marked ✓"
	
	_update_confirm_button()
	print("Least favorite marked at: ", spherical_coords)


func _place_dome_marker(position: Vector3, color: Color, is_favorite: bool) -> void:
	"""Place a visual marker at the selected dome location"""
	var marker = favorite_marker if is_favorite else least_favorite_marker
	
	if marker == null:
		# Create new marker
		marker = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		marker.mesh = sphere
		
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 4.0
		marker.set_surface_override_material(0, material)
		
		# Add to scene (either to dome or target controller)
		if dome_collider:
			dome_collider.add_child(marker)
		else:
			target_controller.add_child(marker)
		
		if is_favorite:
			favorite_marker = marker
		else:
			least_favorite_marker = marker
	
	# Update marker position
	marker.global_position = position
	marker.visible = true