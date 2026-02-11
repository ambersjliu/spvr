extends Node
# GameManager - Autoload Singleton
# Manages overall experiment flow, trial sequencing, and state

enum ExperimentPhase {
	SETUP,
	HIGH_RES_RANKING,
	LOW_RES_RANKING,
	COMPLETE
}

enum TrialType {
	HIGH_RES,  # Constrained points, pairwise comparison
	LOW_RES    # Free selection, favorite/least favorite
}

var current_phase: ExperimentPhase = ExperimentPhase.SETUP
var current_trial: int = 0
var participant_id: String = ""

# Scene management
var all_scenes: Array[String] = []  # Paths to all 360 photos
var high_res_scenes: Array[String] = []  # Subset for high-res ranking
var current_scene_index: int = -1


# Target indices 
var target_pairs = []
var total_targets = global.ANGLED_UP_TARGETS + global.HORIZONTAL_TARGETS + global.VERTICAL_TARGETS
var total_target_pairs = total_targets * (total_targets-1) / 2

# Signals for communication between systems
signal phase_changed(new_phase: ExperimentPhase)
signal trial_started(trial_data: Dictionary)
signal trial_completed(trial_data: Dictionary)
signal scene_changed(scene_path: String)
signal experiment_completed()


func _ready() -> void:
	print("GameManager initialized")



func initialize_experiment(p_id: String, scene_paths: Array[String], high_res_subset: Array[String]) -> void:
	"""Initialize experiment with participant data and scene lists"""
	participant_id = p_id
	all_scenes = scene_paths
	high_res_scenes = high_res_subset
	current_trial = 0
	current_scene_index = -1
	
	print("Experiment initialized for participant: ", participant_id)
	print("Total scenes: ", all_scenes.size())
	print("High-res scenes: ", high_res_scenes.size())


func start_experiment() -> void:
	"""Begin the experiment flow"""
	change_phase(ExperimentPhase.HIGH_RES_RANKING)


func change_phase(new_phase: ExperimentPhase) -> void:
	"""Transition between experiment phases"""
	current_phase = new_phase
	phase_changed.emit(new_phase)
	
	match new_phase:
		ExperimentPhase.HIGH_RES_RANKING:
			print("Starting high-resolution ranking phase")
			_start_high_res_trials()
		ExperimentPhase.LOW_RES_RANKING:
			print("Starting low-resolution ranking phase")
			_start_low_res_trials()
		ExperimentPhase.COMPLETE:
			print("Experiment complete")
			experiment_completed.emit()


func start_next_trial() -> void:
	"""Advance to the next trial"""
	current_trial += 1
	
	match current_phase:
		ExperimentPhase.HIGH_RES_RANKING:
			_start_high_res_trials()
		ExperimentPhase.LOW_RES_RANKING:
			_start_low_res_trials()


func record_ranking(trial_data: Dictionary) -> void:
	"""Record ranking data from a trial"""
	# Add trial metadata
	trial_data["participant_id"] = participant_id
	trial_data["trial_number"] = current_trial
	trial_data["timestamp"] = Time.get_unix_time_from_system()
	
	# Emit for data collection system
	trial_completed.emit(trial_data)
	
	# Save to ExperimentData singleton
	#ExperimentData.add_trial_result(trial_data)


func load_scene(scene_path: String) -> void:
	"""Request scene texture change"""
	scene_changed.emit(scene_path)


# Private helper methods
func _create_shuffled_pairs():
	target_pairs = []
	for i in range(total_targets):
		for j in range(i+1, total_targets):
			target_pairs.append([i, j])
	target_pairs.shuffle()


func _start_high_res_trials() -> void:
	"""Initialize high-resolution ranking trials"""
	if current_trial >= total_target_pairs:
		# High-res phase complete, move to low-res
		current_trial = 0
		change_phase(ExperimentPhase.LOW_RES_RANKING)
		return
	
	var idx = current_trial % total_target_pairs
	
	if idx == 0:
		current_scene_index += 1
		_create_shuffled_pairs()


	var scene_path = high_res_scenes[current_scene_index]

	if idx == 0:
		load_scene(scene_path)
	
	# Create trial data structure
	var trial_data = {
		"type": TrialType.HIGH_RES,
		"scene": scene_path,
		"target_pair": _get_target_pair_for_trial(idx)
	}
	
	trial_started.emit(trial_data)


func _start_low_res_trials() -> void:
	"""Initialize low-resolution ranking trials"""
	if current_trial >= all_scenes.size():
		# All trials complete
		change_phase(ExperimentPhase.COMPLETE)
		return
	
	var scene_path = all_scenes[current_trial % all_scenes.size()]
	
	var trial_data = {
		"type": TrialType.LOW_RES,
		"scene": scene_path
	}
	
	load_scene(scene_path)
	trial_started.emit(trial_data)


#func _get_total_high_res_trials() -> int:
	#"""Calculate total number of high-res trials needed"""
	## For each scene, need to compare all target pairs
	## 16 POIs (8 horizontal + 6 angled + 2 vertical) = 120 comparisons per scene
	## But you might want to use a subset or ranking algorithm
	#var pois_per_scene = 16 
	#var comparisons_per_scene = (pois_per_scene * (pois_per_scene - 1)) / 2
	#return high_res_scenes.size() * comparisons_per_scene


#func _get_total_low_res_trials() -> int:
	#"""Calculate total number of low-res trials"""
	## One trial per scene (select favorite + least favorite)
	#return all_scenes.size()


func _get_target_pair_for_trial(trial_num: int) -> Dictionary:
	"""Determine which target pair to present for a given trial number"""
	# This is simplified - you'd implement your counterbalancing logic here
	var pair = target_pairs[trial_num]
	
	return {
		"target_a_index": pair[0],
		"target_b_index": pair[1]
	}
