// Port of ElevatorGenerator.gd: a two-floor elevator car beside room (20,-10),
// with sliding double doors, an in-car button panel, and moving colliders.
// World-space boxes are rebuilt each frame into CollisionWorld.dynamicBoxes.
import * as THREE from 'three';
import {
  WALL_COLOR_LINEAR,
  ELEVATOR_CENTER_X,
  ELEVATOR_CENTER_Z,
  ELEVATOR_BASE_CAR_Y,
  ELEVATOR_FLOOR_HEIGHT,
  ELEVATOR_FLOORS,
  ELEVATOR_HALF_W,
  ELEVATOR_HALF_D,
  ELEVATOR_HALF_H,
  ELEVATOR_T,
  ELEVATOR_DOOR_W,
  ELEVATOR_DOOR_H,
  ELEVATOR_MOVE_SECONDS,
  ELEVATOR_DOOR_SECONDS,
  ELEVATOR_PAUSE_SECONDS,
  CAPSULE_HEIGHT,
} from '../config.js';
import type { AABBBox } from '../player/Colliders.js';
import type { Interactable } from '../interaction/Interactable.js';

const CX = ELEVATOR_CENTER_X;
const CZ = ELEVATOR_CENTER_Z;

// ElevatorGenerator.gd scene state: num_floors 2 (scene), elevator 3x2.5x2
// local scaled 2x -> 6 wide (Z), 4 deep (X), 5 tall; doors face the museum.
const DOOR_HALF = ELEVATOR_DOOR_W / 2;
const SLIDE = DOOR_HALF; // each panel retreats by half a door width

type Phase = 'idle' | 'closing' | 'waiting' | 'moving' | 'opening';

function easeInOutSine(t: number): number {
  return 0.5 - 0.5 * Math.cos(Math.PI * t);
}

interface CarBox {
  x: number;
  y: number;
  z: number;
  sx: number;
  sy: number;
  sz: number;
}

export class Elevator {
  readonly group = new THREE.Group();
  readonly interactables: Interactable[] = [];
  /** Collider boxes for car + doors, refreshed every frame. */
  readonly dynamicBoxes: AABBBox[] = [];

  private readonly carGroup = new THREE.Group();
  private readonly doorPanels: THREE.Mesh[] = [];
  private readonly buttonMats: THREE.MeshLambertMaterial[] = [];
  private readonly carBoxes: CarBox[] = [];
  private doorSlide = 1; // 0 closed .. 1 open; Godot snaps doors open at setup
  private carY = ELEVATOR_BASE_CAR_Y;
  private cur = 0;
  private target = 0;
  private phase: Phase = 'idle';
  private phaseT = 0;
  private playerInside = false;

  constructor() {
    this.buildCar();
    this.buildShaft();
    this.buildButtons();
    this.group.add(this.carGroup);
    this.syncCar();
  }

  private wallMat(): THREE.MeshLambertMaterial {
    const m = new THREE.MeshLambertMaterial();
    m.color.setRGB(
      WALL_COLOR_LINEAR.r,
      WALL_COLOR_LINEAR.g,
      WALL_COLOR_LINEAR.b,
      THREE.LinearSRGBColorSpace,
    );
    return m;
  }

  private addBox(
    x: number,
    y: number,
    z: number,
    sx: number,
    sy: number,
    sz: number,
    mat: THREE.Material,
    parent: THREE.Object3D = this.carGroup,
  ): THREE.Mesh {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), mat);
    mesh.position.set(x, y, z);
    parent.add(mesh);
    return mesh;
  }

  private buildCar(): void {
    // Light neutral interior so the car reads clearly against purple rooms
    const wallMat = new THREE.MeshLambertMaterial();
    wallMat.color.setRGB(0.72, 0.72, 0.74, THREE.LinearSRGBColorSpace);
    const floorMat = new THREE.MeshLambertMaterial();
    floorMat.color.setRGB(0.5, 0.5, 0.5, THREE.LinearSRGBColorSpace); // scene floor_material
    const ceilMat = new THREE.MeshLambertMaterial();
    ceilMat.color.setRGB(0.8, 0.8, 0.8, THREE.LinearSRGBColorSpace); // scene ceiling_material
    const doorMat = new THREE.MeshLambertMaterial();
    doorMat.color.setRGB(0.35, 0.35, 0.38, THREE.LinearSRGBColorSpace); // door_mat albedo
    const lightMat = new THREE.MeshLambertMaterial();
    lightMat.color.setRGB(1, 1, 1, THREE.LinearSRGBColorSpace);
    lightMat.emissive.setRGB(1, 0.98, 0.92, THREE.LinearSRGBColorSpace);
    lightMat.emissiveIntensity = 0.9;

    const hw = ELEVATOR_HALF_W;
    const hd = ELEVATOR_HALF_D;
    const hh = ELEVATOR_HALF_H;
    const t = ELEVATOR_T;
    // front wall local -X; door centered at z = 0
    const jambW = (hd * 2 + t * 2 - ELEVATOR_DOOR_W) / 2; // 2.7
    const lintelH = hh * 2 - ELEVATOR_DOOR_H; // 0.2

    // floor / ceiling: (width, t, depth) local -> (4 X, 0.3 Y, 6 Z)
    this.carBoxes.push({ x: 0, y: -hh + t / 2, z: 0, sx: hw * 2, sy: t, sz: hd * 2 });
    this.carBoxes.push({ x: 0, y: hh - t / 2, z: 0, sx: hw * 2, sy: t, sz: hd * 2 });
    this.addBox(0, -hh + t / 2, 0, hw * 2, t, hd * 2, floorMat);
    this.addBox(0, hh - t / 2, 0, hw * 2, t, hd * 2, ceilMat);
    // ceiling light fixture
    this.addBox(-0.4, hh - t - 0.02, 0, 1.2, 0.04, 1.6, lightMat);

    // back wall (solid, local +X), spans full depth incl. corners
    this.carBoxes.push({ x: hw - t / 2, y: 0, z: 0, sx: t, sy: hh * 2, sz: hd * 2 + t * 2 });
    this.addBox(hw - t / 2, 0, 0, t, hh * 2, hd * 2 + t * 2, wallMat);

    // side walls (local +/-Z) with windows: opening 2.6 wide, 1.8 tall,
    // sill 1.0 above the car floor
    const winHalf = 1.3;
    const winSill = -hh + t + 1.0; // -1.2 local
    const winTop = winSill + 1.8; // 0.6 local
    for (const s of [-1, 1]) {
      const wz = s * (hd - t / 2);
      // full-height side segments left/right of the window
      const segW = hw - winHalf; // 0.7
      for (const sx of [-1, 1]) {
        this.carBoxes.push({
          x: sx * (hw - segW / 2),
          y: 0,
          z: wz,
          sx: segW,
          sy: hh * 2,
          sz: t,
        });
        this.addBox(sx * (hw - segW / 2), 0, wz, segW, hh * 2, t, wallMat);
      }
      // sill (below window) and header (above window)
      const sillH = winSill - -hh; // 1.3
      this.carBoxes.push({ x: 0, y: -hh + sillH / 2, z: wz, sx: winHalf * 2, sy: sillH, sz: t });
      this.addBox(0, -hh + sillH / 2, wz, winHalf * 2, sillH, t, wallMat);
      const headH = hh - winTop; // 1.9
      this.carBoxes.push({ x: 0, y: winTop + headH / 2, z: wz, sx: winHalf * 2, sy: headH, sz: t });
      this.addBox(0, winTop + headH / 2, wz, winHalf * 2, headH, t, wallMat);
    }

    // front wall jambs + lintel (local -X, doorway at z 0)
    for (const s of [-1, 1]) {
      this.carBoxes.push({
        x: -hw + t / 2,
        y: 0,
        z: s * (DOOR_HALF + jambW / 2),
        sx: t,
        sy: hh * 2,
        sz: jambW,
      });
      this.addBox(-hw + t / 2, 0, s * (DOOR_HALF + jambW / 2), t, hh * 2, jambW, wallMat);
    }
    this.carBoxes.push({
      x: -hw + t / 2,
      y: hh - lintelH / 2,
      z: 0,
      sx: t,
      sy: lintelH,
      sz: ELEVATOR_DOOR_W,
    });
    this.addBox(-hw + t / 2, hh - lintelH / 2, 0, t, lintelH, ELEVATOR_DOOR_W, wallMat);

    // sliding door panels (embedded in the front wall plane)
    for (const s of [-1, 1]) {
      const panel = this.addBox(
        -hw + t / 2,
        0,
        s * DOOR_HALF,
        t / 2,
        ELEVATOR_DOOR_H - 0.01,
        DOOR_HALF - 0.01,
        doorMat,
      );
      this.doorPanels.push(panel);
    }
  }

  private buildShaft(): void {
    // Encloses the travel volume; static, unreachable (car walls seal it).
    // No west wall: the museum room walls + the car front wall seal that side
    // (their doorways align), so a slab here would block the room doorway.
    const wallMat = this.wallMat();
    const mx = ELEVATOR_HALF_W + 0.2;
    const mz = ELEVATOR_HALF_D + 0.2;
    const y0 = ELEVATOR_BASE_CAR_Y - ELEVATOR_HALF_H - 0.15;
    const y1 = ELEVATOR_BASE_CAR_Y + ELEVATOR_FLOOR_HEIGHT + ELEVATOR_HALF_H + 0.3;
    const h = y1 - y0;
    const yC = (y0 + y1) / 2;
    // North/south z-walls start at the room wall's outer face (25.0) so they
    // never poke through into the room interior; a full-height window slot
    // (matching the car windows) lets the car view out while traveling.
    const roomWallX = 25.0;
    const slotHalf = 1.3;
    const eastX = CX + mx + 0.3;
    const leftSpan = CX - slotHalf - roomWallX;
    const rightSpan = eastX - (CX + slotHalf);
    for (const zWall of [CZ - mz - 0.15, CZ + mz + 0.15]) {
      if (leftSpan > 0.01) {
        this.addBox(roomWallX + leftSpan / 2, yC, zWall, leftSpan, h, 0.3, wallMat, this.group);
      }
      if (rightSpan > 0.01) {
        this.addBox(CX + slotHalf + rightSpan / 2, yC, zWall, rightSpan, h, 0.3, wallMat, this.group);
      }
    }
    this.addBox(CX + mx + 0.15, yC, CZ, 0.3, h, mz * 2 + 0.3, wallMat, this.group);
    this.addBox(CX, y1 + 0.15, CZ, mx * 2 + 0.6, 0.3, mz * 2 + 0.6, wallMat, this.group);
    this.addBox(CX, y0 - 0.15, CZ, mx * 2 + 0.6, 0.3, mz * 2 + 0.6, wallMat, this.group);
  }

  private buildButtons(): void {
    // Panel on the side wall next to the door (classic elevator spot),
    // digits stacked top->bottom = 2..1, facing +Z into the car
    const cols = 1;
    const spacingV = 0.44;
    // Side wall (-Z) inner face at z = -(hd - t); sit just proud of it
    const btnZ = -(ELEVATOR_HALF_D - ELEVATOR_T) - 0.02;
    // Near the door side (front wall inner face at x = -hw + t)
    const btnX = -ELEVATOR_HALF_W + ELEVATOR_T + 0.3;
    // Eye level when standing on the car floor: -hh + t + ~1.15
    const startY = -ELEVATOR_HALF_H + ELEVATOR_T + 1.15;
    const pickMat = new THREE.MeshBasicMaterial({ transparent: true, opacity: 0 });

    for (let i = 0; i < ELEVATOR_FLOORS; i++) {
      const row = Math.floor(i / cols);
      const mat = new THREE.MeshLambertMaterial();
      mat.color.setRGB(0.2, 0.2, 0.2, THREE.LinearSRGBColorSpace);
      mat.emissive.setRGB(0, 0, 0);
      const btn = this.addBox(
        btnX,
        startY + row * spacingV,
        btnZ,
        0.24,
        0.24,
        0.04,
        mat,
      );
      this.buttonMats.push(mat);
      this.addLabel(String(i + 1), btn.position.x, btn.position.y, btn.position.z - 0.045);
      // Generous invisible pick target (Godot used an Area3D larger than the button)
      const pickBox = this.addBox(btn.position.x, btn.position.y, btn.position.z - 0.02, 0.4, 0.4, 0.08, pickMat);
      this.interactables.push({
        pickMeshes: [pickBox],
        onHover: () => this.updateButtonColors(i),
        onUnhover: () => this.updateButtonColors(-1),
        onClick: () => this.pressButton(i),
      });
    }
    this.updateButtonColors(-1);
  }

  private addLabel(text: string, x: number, y: number, z: number): void {
    const canvas = document.createElement('canvas');
    canvas.width = 64;
    canvas.height = 64;
    const ctx = canvas.getContext('2d')!;
    ctx.fillStyle = '#ffffff';
    ctx.font = 'bold 44px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, 32, 34);
    const tex = new THREE.CanvasTexture(canvas);
    tex.colorSpace = THREE.SRGBColorSpace;
    const plane = new THREE.Mesh(
      new THREE.PlaneGeometry(0.2, 0.2),
      new THREE.MeshBasicMaterial({ map: tex, transparent: true }),
    );
    plane.position.set(x, y, z); // faces +Z into the car
    this.carGroup.add(plane);
  }

  pressButton(index: number): void {
    if (!this.playerInside) return;
    if (this.phase !== 'idle') return;
    if (index === this.cur) return;
    this.target = index;
    this.phase = 'closing';
    this.phaseT = 0;
  }

  private updateButtonColors(hovered: number): void {
    for (let i = 0; i < this.buttonMats.length; i++) {
      const mat = this.buttonMats[i];
      if (i === hovered && i !== this.cur) {
        mat.emissive.setRGB(0, 0.6, 1, THREE.LinearSRGBColorSpace); // button_highlight_color
        mat.emissiveIntensity = 1;
      } else if (i === this.cur) {
        mat.emissive.setRGB(1, 0.85, 0, THREE.LinearSRGBColorSpace); // button_active_color
        mat.emissiveIntensity = 1;
      } else {
        mat.emissive.setRGB(0, 0, 0);
        mat.emissiveIntensity = 1;
      }
    }
  }

  /** Called every frame before player physics. */
  update(dt: number, playerCenter: { x: number; y: number; z: number }): void {
    if (this.phase !== 'idle') {
      this.phaseT += dt;
      if (this.phase === 'closing') {
        this.doorSlide = 1 - Math.min(1, this.phaseT / ELEVATOR_DOOR_SECONDS);
        // Door sensor: never close on a player standing in the doorway
        if (this.playerInDoorway(playerCenter)) {
          this.phase = 'opening';
          this.phaseT = this.doorSlide * ELEVATOR_DOOR_SECONDS;
        } else if (this.phaseT >= ELEVATOR_DOOR_SECONDS) {
          this.phase = 'waiting';
          this.phaseT = 0;
        }
      } else if (this.phase === 'waiting') {
        this.doorSlide = 0;
        if (this.phaseT >= ELEVATOR_PAUSE_SECONDS) {
          this.phase = 'moving';
          this.phaseT = 0;
        }
      } else if (this.phase === 'moving') {
        const t = Math.min(1, this.phaseT / ELEVATOR_MOVE_SECONDS);
        this.carY =
          ELEVATOR_BASE_CAR_Y +
          (this.cur + (this.target - this.cur) * easeInOutSine(t)) * ELEVATOR_FLOOR_HEIGHT;
        if (this.phaseT >= ELEVATOR_MOVE_SECONDS) {
          this.carY = ELEVATOR_BASE_CAR_Y + this.target * ELEVATOR_FLOOR_HEIGHT;
          this.phase = 'opening';
          this.phaseT = 0;
        }
      } else if (this.phase === 'opening') {
        this.doorSlide = Math.min(1, this.phaseT / ELEVATOR_DOOR_SECONDS);
        if (this.phaseT >= ELEVATOR_DOOR_SECONDS) {
          this.phase = 'idle';
          this.cur = this.target;
          this.doorSlide = 1;
        }
      }
    }

    this.playerInside = this.checkPlayerInside(playerCenter);
    this.syncCar();
    this.rebuildDynamicBoxes();
  }

  private checkPlayerInside(p: { x: number; y: number; z: number }): boolean {
    const half = { x: 0.55, y: CAPSULE_HEIGHT / 2, z: 0.55 };
    return (
      Math.abs(p.x - CX) < ELEVATOR_HALF_W - 0.4 + half.x &&
      Math.abs(p.z - CZ) < ELEVATOR_HALF_D - 0.4 + half.z &&
      p.y + half.y > this.carY - ELEVATOR_HALF_H &&
      p.y - half.y < this.carY + ELEVATOR_HALF_H
    );
  }

  /** True when the player is standing in the open doorway strip. */
  private playerInDoorway(p: { x: number; y: number; z: number }): boolean {
    const doorX = CX - ELEVATOR_HALF_W + ELEVATOR_T / 2;
    return (
      Math.abs(p.x - doorX) < 1.0 &&
      Math.abs(p.z - CZ) < DOOR_HALF + 0.25 &&
      p.y > this.carY - ELEVATOR_HALF_H - 0.5 &&
      p.y < this.carY + ELEVATOR_HALF_H + 0.5
    );
  }

  private syncCar(): void {
    this.carGroup.position.set(CX, this.carY, CZ);
    for (let i = 0; i < this.doorPanels.length; i++) {
      const s = i === 0 ? -1 : 1;
      this.doorPanels[i].position.z = s * (DOOR_HALF + this.doorSlide * SLIDE);
    }
  }

  private rebuildDynamicBoxes(): void {
    const boxes = this.dynamicBoxes;
    boxes.length = 0;
    for (const b of this.carBoxes) {
      boxes.push({
        minX: CX + b.x - b.sx / 2,
        minY: this.carY + b.y - b.sy / 2,
        minZ: CZ + b.z - b.sz / 2,
        maxX: CX + b.x + b.sx / 2,
        maxY: this.carY + b.y + b.sy / 2,
        maxZ: CZ + b.z + b.sz / 2,
      });
    }
    // Door panels move with the slide offset; panel z half-extent = (DOOR_HALF - 0.01) / 2
    const panelZH = (DOOR_HALF - 0.01) / 2;
    for (let i = 0; i < this.doorPanels.length; i++) {
      const panel = this.doorPanels[i];
      boxes.push({
        minX: CX + panel.position.x - 0.075,
        minY: this.carY + panel.position.y - 2.395,
        minZ: CZ + panel.position.z - panelZH,
        maxX: CX + panel.position.x + 0.075,
        maxY: this.carY + panel.position.y + 2.395,
        maxZ: CZ + panel.position.z + panelZH,
      });
    }
  }
}
