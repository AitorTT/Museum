@tool
extends Resource
class_name RoomLayout

@export var width: float = 8.0
@export var height: float = 3.0
@export var depth: float = 6.0
@export var wall_thickness: float = 0.15

@export var wall_material: Material
@export var floor_material: Material
@export var ceiling_material: Material

@export var door_x_pos: bool = false
@export var door_x_neg: bool = false
@export var door_z_pos: bool = false
@export var door_z_neg: bool = false
@export var door_width: float = 0.9
@export var door_height: float = 2.0

@export var window_x_pos: bool = false
@export var window_x_neg: bool = false
@export var window_z_pos: bool = false
@export var window_z_neg: bool = false
@export var window_width: float = 1.2
@export var window_height: float = 1.0
@export var window_bottom: float = 0.8

@export var painting_x_pos: bool = false
@export var painting_x_pos_texture: Texture2D
@export var painting_x_neg: bool = false
@export var painting_x_neg_texture: Texture2D
@export var painting_z_pos: bool = false
@export var painting_z_pos_texture: Texture2D
@export var painting_z_neg: bool = false
@export var painting_z_neg_texture: Texture2D
@export var painting_ceiling: bool = false
@export var painting_ceiling_texture: Texture2D
@export var painting_height: float = 1.5
@export var painting_scale: float = 0.4
@export var painting_offset_h: float = 0.0
@export var painting_offset_v: float = 0.0

@export var light_x_pos: bool = false
@export var light_x_neg: bool = false
@export var light_z_pos: bool = false
@export var light_z_neg: bool = false
@export var light_ceiling: bool = false
@export var light_type: String = "Spot"
@export var light_energy: float = 10.0
@export var light_color: Color = Color(1, 1, 1)
@export var light_range: float = 8.0
