// Minimal swept AABB collision, replacing Godot's CharacterBody3D.move_and_slide.
// The whole museum is axis-aligned boxes, so per-axis resolve is exact.
import type * as THREE from 'three';

export interface AABBBox {
  minX: number;
  minY: number;
  minZ: number;
  maxX: number;
  maxY: number;
  maxZ: number;
}

const EPS = 1e-4;

export class CollisionWorld {
  readonly boxes: AABBBox[] = [];
  /** Moving colliders (elevator car/doors), refreshed externally each frame. */
  dynamicBoxes: AABBBox[] = [];

  addBox(cx: number, cy: number, cz: number, sx: number, sy: number, sz: number): void {
    this.boxes.push({
      minX: cx - sx / 2,
      minY: cy - sy / 2,
      minZ: cz - sz / 2,
      maxX: cx + sx / 2,
      maxY: cy + sy / 2,
      maxZ: cz + sz / 2,
    });
  }

  /**
   * Moves `pos` (player AABB center) by `delta`, resolving collisions per axis
   * (X, Z, then Y). Returns true when the player landed on ground this move.
   */
  move(pos: THREE.Vector3, half: { x: number; y: number; z: number }, delta: THREE.Vector3): boolean {
    pos.x += delta.x;
    if (delta.x !== 0) this.resolveAxis(pos, half, 0, delta.x);

    pos.z += delta.z;
    if (delta.z !== 0) this.resolveAxis(pos, half, 2, delta.z);

    pos.y += delta.y;
    let onGround = false;
    if (delta.y !== 0) {
      const hit = this.resolveAxis(pos, half, 1, delta.y);
      if (hit && delta.y < 0) onGround = true;
    }
    return onGround;
  }

  private resolveAxis(
    pos: THREE.Vector3,
    half: { x: number; y: number; z: number },
    axis: 0 | 1 | 2,
    amount: number,
  ): boolean {
    let hit = false;
    for (const b of this.boxes) {
      if (this.resolveOne(pos, half, axis, amount, b)) hit = true;
    }
    for (const b of this.dynamicBoxes) {
      if (this.resolveOne(pos, half, axis, amount, b)) hit = true;
    }
    return hit;
  }

  private resolveOne(
    pos: THREE.Vector3,
    half: { x: number; y: number; z: number },
    axis: 0 | 1 | 2,
    amount: number,
    b: AABBBox,
  ): boolean {
    const pminX = pos.x - half.x;
    const pmaxX = pos.x + half.x;
    const pminY = pos.y - half.y;
    const pmaxY = pos.y + half.y;
    const pminZ = pos.z - half.z;
    const pmaxZ = pos.z + half.z;
    if (pminX >= b.maxX || pmaxX <= b.minX) return false;
    if (pminY >= b.maxY || pmaxY <= b.minY) return false;
    if (pminZ >= b.maxZ || pmaxZ <= b.minZ) return false;
    if (axis === 0) {
      pos.x = amount > 0 ? b.minX - half.x - EPS : b.maxX + half.x + EPS;
    } else if (axis === 1) {
      pos.y = amount > 0 ? b.minY - half.y - EPS : b.maxY + half.y + EPS;
    } else {
      pos.z = amount > 0 ? b.minZ - half.z - EPS : b.maxZ + half.z + EPS;
    }
    return true;
  }
}
