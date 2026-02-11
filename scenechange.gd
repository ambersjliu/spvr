extends MeshInstance3D

@export var skybox_material: StandardMaterial3D = load('res://360scenes/skybox_material.tres')
var current_texture: Texture2D
var scene_paths = ['res://models/Attempt1_WorldTexture - Copy.jpg', 'res://models/Attempt1_WorldTexture.jpg']
var currScene = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	material_override = skybox_material
	current_texture = load(scene_paths[currScene]) as Texture2D
	skybox_material.albedo_texture = current_texture
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func changeScene():
	if currScene == 0:
		currScene = 1
	else:
		currScene = 0
	current_texture = load(scene_paths[currScene]) as Texture2D
	skybox_material.albedo_texture = current_texture


func _on_color_change_cube_cube_hit() -> void:
	changeScene()
	
