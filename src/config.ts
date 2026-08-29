// Port of RoomGenerator.gd scene overrides + character_body_3d.gd exports.

// Room dimensions (RoomGenerator.tscn overrides)
export const ROOM_WIDTH = 10.0;
export const ROOM_HEIGHT = 6.0;
export const ROOM_DEPTH = 10.0;
export const WALL_T = 0.15;

// Doors (scene overrides; MuseumBuilder sets door_width = 2.0 at build time)
export const DOOR_WIDTH = 2.0;
export const DOOR_HEIGHT = 3.0;

// Windows (scene overrides: width 12 -> clamped per wall, height 5, bottom 2)
export const WINDOW_WIDTH = 12.0;
export const WINDOW_HEIGHT = 5.0;
export const WINDOW_BOTTOM = 2.0;

// Paintings
export const PAINTING_HEIGHT = 2.0;
export const PAINTING_SCALE = 2.0;
export const FRAME_PADDING = 0.05;
export const FRAME_DEPTH = 0.08;
export const FRAME_COLOR_LINEAR = { r: 0.2, g: 0.2, b: 0.2 };
export const HOVER_GLOW_LINEAR = { r: 1.0, g: 0.9, b: 0.6 };
export const HOVER_GLOW_STRENGTH = 1.5;

// Materials (DullWhite1.tres: albedo 0.298, 0, 0.506 in linear space)
export const WALL_COLOR_LINEAR = { r: 0.29803923, g: 0.0, b: 0.5058824 };
export const FLOOR_UV_SCALE = 2.0; // uv1_scale of the floor material (triplanar)
export const DEFAULT_SEGMENT_COLOR_LINEAR = { r: 0.8, g: 0.8, b: 0.8 };

// Lights (Godot used baked LightmapGI + ceiling spots; we approximate with cheap ambient)
export const AMBIENT_INTENSITY = 0.9;
export const HEMI_INTENSITY = 1.1;
export const HEMI_GROUND_LINEAR = { r: 0.35, g: 0.35, b: 0.4 };

// Player (character_body_3d.gd exports + player.tscn)
export const PLAYER_SPEED = 7.0;
export const PLAYER_ROTATION_SPEED = 3.0; // rad/s at full joystick deflection
export const PLAYER_GRAVITY = 9.8 * 3;
export const MAX_PITCH_DEG = 45.0;
export const MOUSE_SENSITIVITY = 0.005;
export const FALL_RESPAWN_SECONDS = 2.0;

// player.tscn geometry (default capsule r=0.5 h=2.0, node scaled 1.1x in main scene)
export const PLAYER_SCALE = 1.1;
export const CAPSULE_RADIUS = 0.5 * PLAYER_SCALE;
export const CAPSULE_HEIGHT = 2.0 * PLAYER_SCALE;
export const CAMERA_LOCAL_Y = 1.60862 * PLAYER_SCALE;
export const CAMERA_LOCAL_Z = -1.09669 * PLAYER_SCALE; // -Z = forward
export const INITIAL_PITCH = -0.281186; // camera arm baked tilt (~16 deg down)
export const CAMERA_FOV = 50.0;

// Spawn: PLAYER instance transform in RoomGenerator.tscn, feet placed on floor 1
export const SPAWN_X = -3.1290083;
export const SPAWN_Z = -8.900534;
export const SPAWN_YAW = Math.PI / 2; // face -X world (Godot basis z-axis -> +X)

// World
export const SKY_COLOR = 0x393939; // Godot default clear color

// Painting textures location under public/
export const PAINTINGS_DIR = 'paintings';
export const FLOOR_TEXTURE = 'textures/floor_wall1.jpg';
