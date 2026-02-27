# llm generated - may not use at all but helpful for reference

extends Control
# ExperimentStarter - Handles experiment initialization with intro screen
# Manages participant ID auto-increment and data persistence

@export var intro_panel: Panel
@export var start_button: Button
@export var info_label: Label
@export var participant_label: Label

# Scene configuration
@export var scene_directory: String = "res://resources/360_photos/"
@export var auto_scan_scenes: bool = false
@export_file("*.jpg", "*.png") var manual_scene_paths: Array[String] = []
@export var high_res_scene_indices: Array[int] = [0, 1]

var participant_id: String = ""
var is_experiment_active: bool = false


func _ready() -> void:
	# Get next participant ID
	participant_id = "0"
	
	# Update UI
	if participant_label:
		participant_label.text = "Participant ID: " + participant_id
	
	if info_label:
		info_label.text = _get_intro_text()
	
	# Connect start button
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	
	# Show intro panel
	if intro_panel:
		intro_panel.visible = true
	
	print("=== Experiment Ready ===")
	print("Participant ID: ", participant_id)
	print("Data will be saved to: ", ExperimentData.get_data_file_path())


func _get_intro_text() -> String:
	"""Generate intro text explaining the experiment"""
	return """Some text about the experiment! Press Start to get started!"""


func _on_start_button_pressed() -> void:
	"""Start the experiment when participant clicks the button"""
	if is_experiment_active:
		return
	
	print("Starting experiment...")
	
	# Hide intro panel
	if intro_panel:
		intro_panel.visible = false
	
	# Gather scene paths
	var all_scenes: Array[String] = []
	if auto_scan_scenes:
		all_scenes = _scan_scene_directory()
	else:
		all_scenes = manual_scene_paths
	
	if all_scenes.is_empty():
		push_error("No scenes found! Check your scene directory or manual paths.")
		_show_error("No scenes found! Please check configuration.")
		return
	
	# Select high-res subset
	var high_res_scenes: Array[String] = []
	for idx in high_res_scene_indices:
		if idx < all_scenes.size():
			high_res_scenes.append(all_scenes[idx])
	
	if high_res_scenes.is_empty():
		push_warning("No high-res scenes selected. Using first 3 scenes as default.")
		high_res_scenes = all_scenes.slice(0, min(3, all_scenes.size()))
	
	# Set up experiment metadata
	#ExperimentData.set_metadata("participant_id", participant_id)
	#ExperimentData.set_metadata("start_time", Time.get_datetime_string_from_system())
	#ExperimentData.set_metadata("godot_version", Engine.get_version_info()["string"])
	#ExperimentData.set_metadata("total_scenes", all_scenes.size())
	#ExperimentData.set_metadata("high_res_scenes", high_res_scenes.size())
	
	# Initialize GameManager
	GameManager.initialize_experiment(participant_id, all_scenes, high_res_scenes)
	
	# Connect to experiment completion
	if not GameManager.experiment_completed.is_connected(_on_experiment_completed):
		GameManager.experiment_completed.connect(_on_experiment_completed)
	
	# Start the experiment
	is_experiment_active = true
	GameManager.start_experiment()
	
	print("=== Experiment Started ===")
	print("Participant: ", participant_id)
	print("Total scenes: ", all_scenes.size())
	print("High-res scenes: ", high_res_scenes.size())


func _scan_scene_directory() -> Array[String]:
	"""Automatically scan directory for 360 image files"""
	var scenes: Array[String] = []
	var dir = DirAccess.open(scene_directory)
	
	if dir == null:
		push_error("Could not open directory: " + scene_directory)
		return scenes
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var extension = file_name.get_extension().to_lower()
			if extension in ["jpg", "jpeg", "png", "webp"]:
				var full_path = scene_directory.path_join(file_name)
				scenes.append(full_path)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	scenes.sort()
	
	print("Found ", scenes.size(), " scene images in ", scene_directory)
	return scenes


func _on_experiment_completed() -> void:
	"""Handle experiment completion"""
	print("=== Experiment Complete ===")
	
	# Show completion message
	if intro_panel:
		intro_panel.visible = true
	
	if info_label:
		info_label.text = "Thank you for participating!\n\nYour data has been saved.\n\nYou may now close the application."
	
	if start_button:
		start_button.visible = false
	
	# Export final data
	#_export_final_data()


func _export_final_data() -> void:
	"""Export final dataset with timestamp"""
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var base_filename = "experiment_" + participant_id + "_" + timestamp
	
	# Create data directory if needed
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("exports"):
		dir.make_dir("exports")
	
	var json_path = "user://exports/" + base_filename + ".json"
	ExperimentData.export_to_json(json_path)
	
	print("Final data exported to: ", ProjectSettings.globalize_path(json_path))


func _show_error(message: String) -> void:
	"""Display error message to user"""
	if info_label:
		info_label.text = "ERROR: " + message


func _notification(what: int) -> void:
	"""Handle application quit - ensure data is saved"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_experiment_active:
			_export_final_data()
