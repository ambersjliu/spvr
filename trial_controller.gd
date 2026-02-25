extends Control
# TrialController - Manages individual trial flow and UI
# Handles high-res and low-res trial types

@onready var camera: Camera3D = %Camera3D
@onready var sphere_controller: Node3D = %SphereController

# UI Elements (assign these in the editor)
@export var instruction_label: Label


var current_trial_data: Dictionary = {}
var trial_type: int  # GameManager.TrialType

# For low-res trials
var selected_favorite: Dictionary = {}
var selected_least_favorite: Dictionary = {}


func _ready() -> void:
	# Connect to GameManager
	GameManager.trial_started.connect(_on_trial_started)
	if target_controller and target_controller.has_signal("target_selected"):
		target_controller.target_selected.connect(_on_target_selected)
	



func _on_trial_started(trial_data: Dictionary) -> void:
	"""Initialize a new trial based on trial data from GameManager"""
	current_trial_data = trial_data
	trial_type = trial_data["type"]
	
	match trial_type:
		GameManager.TrialType.HIGH_RES:
			_setup_high_res_trial()
		GameManager.TrialType.LOW_RES:
			_setup_low_res_trial()


func _setup_high_res_trial() -> void:
	"""Set up a high-resolution pairwise comparison trial"""
	# Show only the relevant UI
	_set_ui_visibility(true, false)
	
	# Get target pair from trial data
	var target_pair = current_trial_data["target_pair"]
	var target_a_index = target_pair["target_a_index"]
	var target_b_index = target_pair["target_b_index"]
	
	# Highlight the target pair
	sphere_controller.highlight_target_pair(target_a_index, target_b_index)
	
	# Update instructions
	if instruction_label:
		instruction_label.text = "Look at each highlighted viewtargetnt.\nWhich view is better?"
	
	# Start by looking at target A
	var target_a_transform = sphere_controller.get_target_transform(target_a_index)
	camera.look_at_target(target_a_transform)


func _setup_low_res_trial() -> void:
	"""Set up a low-resolution free selection trial"""
	# Show low-res UI
	_set_ui_visibility(false, true)
	
	# Show all targets or hide them for free exploration
	sphere_controller.hide_all_targets()  # Hide for free selection
	
	# Reset selections
	selected_favorite = {}
	selected_least_favorite = {}
	
	# Update instructions
	if instruction_label:
		instruction_label.text = "Freely explore the scene.\nMark your favorite and least favorite views."


func _set_ui_visibility(show_high_res: bool, show_low_res: bool) -> void:
	"""Toggle UI elements based on trial type"""



# High-res trial handlers


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

func _record_high_res_choice(choice: String) -> void:
	"""Record the ranking choice and advance to next trial"""
	var target_pair = current_trial_data["target_pair"]
	
	var ranking_data = {
		"type": "high_res",
		"scene": current_trial_data["scene"],
		"target_a_index": target_pair["target_a_index"],
		"target_b_index": target_pair["target_b_index"],
		"choice": choice,
		"response_time": Time.get_ticks_msec()  # You'd want to track start time too
	}
	
	GameManager.record_ranking(ranking_data)
	GameManager.start_next_trial()


# Low-res trial handlers
#
#func _on_mark_favorite_pressed() -> void:
	#"""Mark current view as favorite"""
	#selected_favorite = camera.get_spherical_coordinates()
	#selected_favorite["timestamp"] = Time.get_ticks_msec()
	#
	#if favorite_button:
		#favorite_button.text = "Favorite Marked ✓"
	#
	#_update_confirm_button()
#
#
#func _on_mark_least_favorite_pressed() -> void:
	#"""Mark current view as least favorite"""
	#selected_least_favorite = camera.get_spherical_coordinates()
	#selected_least_favorite["timestamp"] = Time.get_ticks_msec()
	#
	#if least_favorite_button:
		#least_favorite_button.text = "Least Favorite Marked ✓"
	#
	#_update_confirm_button()
#
#
#func _update_confirm_button() -> void:
	#"""Enable confirm button only when both selections are made"""
	#if confirm_button:
		#confirm_button.disabled = selected_favorite.is_empty() or selected_least_favorite.is_empty()
#
#
#func _on_confirm_pressed() -> void:
	#"""Submit low-res trial selections"""
	#var ranking_data = {
		#"type": "low_res",
		#"scene": current_trial_data["scene"],
		#"favorite": selected_favorite,
		#"least_favorite": selected_least_favorite
	#}
	#
	#GameManager.record_ranking(ranking_data)
	#
	## Reset button text
	#if favorite_button:
		#favorite_button.text = "Mark Favorite"
	#if least_favorite_button:
		#least_favorite_button.text = "Mark Least Favorite"
	#
	#GameManager.start_next_trial()
