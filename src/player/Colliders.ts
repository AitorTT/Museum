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
  /** Non-floor colliders (walls, ceiling, elevator car). */
  readonly solidBoxes: AABBBox[] = [];
  /** Walkable-floor colliders; resolved LAST on Y so floors win over walls. */
  readonly floorBoxes: AABBBox[] = [];
  /** Moving colliders (elevator car/doors), refreshed externally each frame. */
  dynamicBoxes: AABBBox[] = [];

  addBox(cx: number, cy: number, cz: number, sx: number, sy: number, sz: number, kind: 'solid' | 'floor' = 'solid'): void {
    const box: AABBBox = {
      minX: cx - sx / 2,
      minY: cy - sy / 2,
      minZ: cz - sz / 2,
      maxX: cx + sx / 2,
      maxY: cy + sy / 2,
      maxZ: cz + sz / 2,
    };
    this.boxes.push(box);
    (kind === 'floor' ? this.floorBoxes : this.solidBoxes).push(box);
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
    // On Y, walkable floors resolve LAST so a wall's downward push can never
    // override the floor supporting the player (order-dependent death spiral).
    const lists: AABBBox[][] =
      axis === 1
        ? [this.solidBoxes, this.dynamicBoxes, this.floorBoxes]
        : [this.boxes, this.dynamicBoxes];
    for (const list of lists) {
      for (const b of list) {
        if (this.resolveOne(pos, half, axis, amount, b)) hit = true;
      }
    }
    return hit;
  }

  /**
   * Minimal-translation resolve: push the player out through the NEAREST face
   * of the box, and only along this pass's axis when that axis is the box's
   * minimal-penetration axis. Walking beside a full-height wall therefore
   * never lets the Y pass shove the player down through the floor.
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

    const penX0 = pmaxX - b.minX;
    const penX1 = b.maxX - pminX;
    const penY0 = b.maxY - pminY;
    const penY1 = pmaxY - b.minY;
    const penZ0 = pmaxZ - b.minZ;
    const penZ1 = b.maxZ - pminZ;
    const penX = Math.min(penX0, penX1);
    const penY = Math.min(penY0, penY1);
    const penZ = Math.min(penZ0, penZ1);
    if (axis === 0 && (penY < penX || penZ < penX)) return false;
    if (axis === 1 && (penX < penY || penZ < penY)) return false;
    if (axis === 2 && (penX < penZ || penY < penZ)) return false;

    if (axis === 0) {
      pos.x = penX0 < penX1 ? b.minX - half.x - EPS : b.maxX + half.x + EPS;
    } else if (axis === 1) {
      pos.y = penY0 < penY1 ? b.maxY + half.y + EPS : b.minY - half.y - EPS;
    } else {
      pos.z = penZ0 < penZ1 ? b.minZ - half.z - EPS : b.maxZ + half.z + EPS;
    }
    return true;
  }
}
