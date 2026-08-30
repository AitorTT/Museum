// Port of Teleporter.gd: pairs of floor pads that swap the player between
// them, with a per-pair cooldown. Pads are flat glowing discs; triggers are
// checked against the player each frame (Godot used Area3D bodies).
import * as THREE from 'three';
import {
  TELEPORT_PAIRS,
  TELEPORT_RADIUS,
  TELEPORT_COOLDOWN,
  floorTopY,
  CAPSULE_HEIGHT,
} from '../config.js';
import type { Player } from '../player/Player.js';

interface Pad {
  x: number;
  z: number;
  topY: number;
}

interface Pair {
  a: Pad;
  b: Pad;
  cooldown: number;
}

export class Teleporters {
  readonly group = new THREE.Group();
  private pairs: Pair[] = [];

  constructor() {
    const padGeo = new THREE.CylinderGeometry(1, 1, 0.06, 24);
    const rimGeo = new THREE.CylinderGeometry(1.12, 1.12, 0.04, 24);
    const padMat = new THREE.MeshBasicMaterial({ color: 0x2fa8d8 });
    const rimMat = new THREE.MeshBasicMaterial({ color: 0x123744 });

    for (const [defA, defB] of TELEPORT_PAIRS) {
      const a = this.addPad(defA, padGeo, rimGeo, padMat, rimMat);
      const b = this.addPad(defB, padGeo, rimGeo, padMat, rimMat);
      this.pairs.push({ a, b, cooldown: 0 });
    }
  }

  private addPad(
    def: { x: number; z: number; floor: number },
    padGeo: THREE.CylinderGeometry,
    rimGeo: THREE.CylinderGeometry,
    padMat: THREE.MeshBasicMaterial,
    rimMat: THREE.MeshBasicMaterial,
  ): Pad {
    const topY = floorTopY(def.floor) + 0.03;
    const rim = new THREE.Mesh(rimGeo, rimMat);
    rim.position.set(def.x, floorTopY(def.floor) + 0.02, def.z);
    this.group.add(rim);
    const pad = new THREE.Mesh(padGeo, padMat);
    pad.position.set(def.x, topY, def.z);
    this.group.add(pad);
    return { x: def.x, z: def.z, topY };
  }

  update(dt: number, player: Player): void {
    const px = player.position.x;
    const pz = player.position.z;
    const feetY = player.position.y - CAPSULE_HEIGHT / 2;

    for (const pair of this.pairs) {
      if (pair.cooldown > 0) {
        pair.cooldown -= dt;
        continue;
      }
      if (this.tryPad(pair, pair.a, pair.b, player, px, pz, feetY)) continue;
      this.tryPad(pair, pair.b, pair.a, player, px, pz, feetY);
    }
  }

  private tryPad(
    pair: Pair,
    from: Pad,
    to: Pad,
    player: Player,
    px: number,
    pz: number,
    feetY: number,
  ): boolean {
    const dx = px - from.x;
    const dz = pz - from.z;
    if (dx * dx + dz * dz > TELEPORT_RADIUS * TELEPORT_RADIUS) return false;
    if (Math.abs(feetY - from.topY) > 0.6) return false;

    // Teleporter.gd: body.global_position = target.global_position + (0, 0.5, 0)
    player.teleportTo(to.x, to.topY + CAPSULE_HEIGHT / 2 + 0.02, to.z);
    pair.cooldown = TELEPORT_COOLDOWN;
    return true;
  }
}