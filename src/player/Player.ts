// Port of SCENES/PLAYER/character_body_3d.gd (desktop + Android behavior).
import * as THREE from 'three';
import {
  PLAYER_SPEED,
  PLAYER_ROTATION_SPEED,
  PLAYER_GRAVITY,
  MAX_PITCH_DEG,
  MOUSE_SENSITIVITY,
  FALL_RESPAWN_SECONDS,
  CAPSULE_RADIUS,
  CAPSULE_HEIGHT,
  CAMERA_EYE_OFFSET_Y,
  CAMERA_LOCAL_Z,
  INITIAL_PITCH,
  CAMERA_FOV,
  SPAWN_X,
  SPAWN_Z,
  SPAWN_YAW,
  ROOM_HEIGHT,
  WALL_T,
} from '../config.js';
import type { CollisionWorld } from './Colliders.js';

const HALF = { x: CAPSULE_RADIUS, y: CAPSULE_HEIGHT / 2, z: CAPSULE_RADIUS };
const MAX_PITCH = (MAX_PITCH_DEG * Math.PI) / 180;
// Walkable surface of floor 1 (floor box top): -HH + thickness
const FLOOR1_TOP = -ROOM_HEIGHT / 2 + WALL_T;

export interface Vec2Like {
  x: number;
  y: number;
}

export class Player {
  readonly yawObject = new THREE.Group();
  readonly camera: THREE.PerspectiveCamera;
  readonly position = new THREE.Vector3();
  readonly velocity = new THREE.Vector3();

  /** Left input: x = strafe, y = forward(-1)/back(+1). Matches Godot's convention. */
  moveInput: Vec2Like = { x: 0, y: 0 };
  /** Right joystick rotation delta, read live each frame (Android only). */
  joystickLook: Vec2Like = { x: 0, y: 0 };

  private yaw = SPAWN_YAW;
  private pitch = INITIAL_PITCH;
  private fallTimer = 0;

  constructor(private world: CollisionWorld) {
    this.camera = new THREE.PerspectiveCamera(CAMERA_FOV, 1, 0.05, 4000);
    // position is the collision AABB center; Godot's eye offset was above feet
    this.camera.position.set(0, CAMERA_EYE_OFFSET_Y, CAMERA_LOCAL_Z);
    this.yawObject.add(this.camera);
    this.respawn();
  }

  onMouseMove(dx: number, dy: number): void {
    this.yaw -= dx * MOUSE_SENSITIVITY;
    this.pitch -= dy * MOUSE_SENSITIVITY;
    this.pitch = Math.min(MAX_PITCH, Math.max(-MAX_PITCH, this.pitch));
  }

  update(dt: number): void {
    // Android rotation (joystick_rotation.gd -> rotation_delta)
    this.yaw -= this.joystickLook.x * PLAYER_ROTATION_SPEED * dt;
    this.pitch -= this.joystickLook.y * PLAYER_ROTATION_SPEED * dt;
    this.pitch = Math.min(MAX_PITCH, Math.max(-MAX_PITCH, this.pitch));
    this.yawObject.rotation.y = this.yaw;

    // Movement (character_body_3d.gd: direction = basis * input, always normalized)
    const dir = new THREE.Vector3(this.moveInput.x, 0, this.moveInput.y);
    if (dir.lengthSq() > 0) {
      dir.normalize().applyQuaternion(this.yawObject.quaternion);
      this.velocity.x = dir.x * PLAYER_SPEED;
      this.velocity.z = dir.z * PLAYER_SPEED;
    } else {
      this.velocity.x = 0;
      this.velocity.z = 0;
    }

    // Gravity always accumulates; floor contact zeroes it (keeps ground detection stable)
    this.velocity.y -= PLAYER_GRAVITY * dt;

    const delta = this.velocity.clone().multiplyScalar(dt);
    const onGround = this.world.move(this.position, HALF, delta);

    if (onGround) {
      this.velocity.y = 0;
      this.fallTimer = 0;
    } else {
      this.fallTimer += dt;
      if (this.fallTimer > FALL_RESPAWN_SECONDS) {
        this.respawn();
      }
    }

    this.yawObject.position.copy(this.position);
    this.camera.rotation.x = this.pitch;
  }

  setPose(x: number, y: number, z: number, yaw = this.yaw, pitch = this.pitch): void {
    this.position.set(x, y, z);
    this.velocity.set(0, 0, 0);
    this.fallTimer = 0;
    this.yaw = yaw;
    this.pitch = pitch;
    this.yawObject.rotation.y = this.yaw;
    this.yawObject.position.copy(this.position);
    this.camera.rotation.x = this.pitch;
  }

  /** Instant repositioning (teleporter pads); keeps current view angles. */
  teleportTo(x: number, y: number, z: number): void {
    this.position.set(x, y, z);
    this.velocity.set(0, 0, 0);
    this.fallTimer = 0;
  }

  respawn(): void {
    this.setPose(SPAWN_X, FLOOR1_TOP + CAPSULE_HEIGHT / 2, SPAWN_Z, SPAWN_YAW, INITIAL_PITCH);
  }
}
