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
      const yBefore = pos.y;
      const hit = this.resolveAxis(pos, half, 1, delta.y);
      // Grounded only when the resolver pushed us UP onto a surface; being
      // ejected downward from a ceiling is not ground.
      if (hit && delta.y < 0 && pos.y >= yBefore) onGround = true;
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

  /**
   * Minimal-translation resolve: push the player out through the NEAREST face
   * of the box, never the far one. An embedded player (spawn/teleport/ride
   * edge cases) is ejected a few centimeters instead of teleported on top of
   * whatever they clipped into.
   */
  private resolveOne(
    pos: THREE.Vector3,
    half: { x: number; y: number; z: number },
    axis: 0 | 1 | 2,
    _amount: number,
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
      const outMin = pmaxX - b.minX; // depth pushing toward -X face
      const outMax = b.maxX - pminX; // depth pushing toward +X face
      pos.x = outMin < outMax ? b.minX - half.x - EPS : b.maxX + half.x + EPS;
    } else if (axis === 1) {
      const outUp = b.maxY - pminY; // depth pushing up onto the top face
      const outDown = pmaxY - b.minY; // depth pushing down under the bottom face
      pos.y = outUp < outDown ? b.maxY + half.y + EPS : b.minY - half.y - EPS;
    } else {
      const outMin = pmaxZ - b.minZ;
      const outMax = b.maxZ - pminZ;
      pos.z = outMin < outMax ? b.minZ - half.z - EPS : b.maxZ + half.z + EPS;
    }
    return true;
  }
}
