// Builds the whole museum: merged static geometry, colliders, and paintings.
// Static lighting is baked into vertex colors (Godot used LightmapGI + ceiling
// spots; this approximates that bake with zero runtime lights).
import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import {
  WALL_COLOR_LINEAR,
  DEFAULT_SEGMENT_COLOR_LINEAR,
  FLOOR_UV_SCALE,
  FLOOR_TEXTURE_BOOST,
  CAPSULE_RADIUS,
  ROOM_HEIGHT,
  WALL_T,
  BAKE_ENERGY,
  BAKE_MIN_DISTANCE,
  BAKE_DIRECT_SCALE,
  BAKE_CONE_INNER,
  BAKE_CONE_OUTER,
  BAKE_BOUNCE_WALL,
  BAKE_BOUNCE_FLOOR,
  BAKE_CEIL_BASE,
  BAKE_CEIL_GLOW,
  BAKE_CEIL_SIGMA2,
  BAKE_MIN,
  BAKE_MAX,
  FLOOR_SEGMENTS,
  WALL_SEGMENTS_H,
  WALL_SEGMENTS_V,
} from '../config.js';
import { MUSEUM } from './layout.js';
import { planRoom, type SegmentBox } from './RoomBuilder.js';
import { Painting } from './Painting.js';
import { CollisionWorld } from '../player/Colliders.js';

function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = Math.min(1, Math.max(0, (x - edge0) / (edge1 - edge0)));
  return t * t * (3 - 2 * t);
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, v));
}

/**
 * Bakes the ceiling spotlight into vertex colors for one box.
 * Floor/walls: cone-weighted E/d^2 falloff + constant bounce.
 * Ceiling: soft gaussian glow under the fixture.
 */
function bakeLightColors(geom: THREE.BufferGeometry, box: SegmentBox): void {
  const pos = geom.attributes.position as THREE.BufferAttribute;
  const colors = new Float32Array(pos.count * 3);
  for (let i = 0; i < pos.count; i++) {
    const wx = pos.getX(i) + box.cx;
    const wy = pos.getY(i) + box.cy;
    const wz = pos.getZ(i) + box.cz;
    let v: number;
    if (box.kind === 'ceiling') {
      const dx = wx - box.lx;
      const dz = wz - box.lz;
      v = BAKE_CEIL_BASE + BAKE_CEIL_GLOW * Math.exp(-(dx * dx + dz * dz) / BAKE_CEIL_SIGMA2);
    } else {
      const dx = wx - box.lx;
      const dy = wy - box.ly;
      const dz = wz - box.lz;
      const d2 = dx * dx + dy * dy + dz * dz;
      const d = Math.max(Math.sqrt(d2), BAKE_MIN_DISTANCE);
      const cosAngle = -dy / d; // light points straight down
      const cone = smoothstep(BAKE_CONE_OUTER, BAKE_CONE_INNER, cosAngle);
      const direct = (BAKE_ENERGY / d2) * BAKE_DIRECT_SCALE * cone;
      const bounce = box.kind === 'floor' ? BAKE_BOUNCE_FLOOR : BAKE_BOUNCE_WALL;
      v = clamp(direct + bounce, BAKE_MIN, BAKE_MAX);
    }
    colors[i * 3] = v;
    colors[i * 3 + 1] = v;
    colors[i * 3 + 2] = v;
  }
  geom.setAttribute('color', new THREE.BufferAttribute(colors, 3));
}

// Repeats the floor texture per world unit (approximates Godot's triplanar uv1_scale=2)
function boxWithTiledUVs(
  sx: number,
  sy: number,
  sz: number,
  wSeg: number,
  hSeg: number,
  dSeg: number,
  uvScale: number,
): THREE.BoxGeometry {
  const geom = new THREE.BoxGeometry(sx, sy, sz, wSeg, hSeg, dSeg);
  const uv = geom.attributes.uv as THREE.BufferAttribute;
  // BoxGeometry face order: +x, -x, +y, -y, +z, -z; each face is a grid of vertices
  const dims: Array<[number, number]> = [
    [sz, sy],
    [sz, sy],
    [sx, sz],
    [sx, sz],
    [sx, sy],
    [sx, sy],
  ];
  const counts: Array<[number, number]> = [
    [dSeg, hSeg],
    [dSeg, hSeg],
    [wSeg, dSeg],
    [wSeg, dSeg],
    [wSeg, hSeg],
    [wSeg, hSeg],
  ];
  let start = 0;
  for (let face = 0; face < 6; face++) {
    const [du, dv] = dims[face];
    const [us, vs] = counts[face];
    const count = (us + 1) * (vs + 1);
    for (let i = start; i < start + count; i++) {
      uv.setXY(i, uv.getX(i) * du * uvScale, uv.getY(i) * dv * uvScale);
    }
    start += count;
  }
  return geom;
}

function segmentGeometry(box: SegmentBox): THREE.BufferGeometry {
  let geom: THREE.BoxGeometry;
  if (box.kind === 'floor' || box.kind === 'ceiling') {
    // Subdivide horizontally so the baked light pool has center vertices
    geom = boxWithTiledUVs(
      box.sx,
      box.sy,
      box.sz,
      FLOOR_SEGMENTS,
      1,
      FLOOR_SEGMENTS,
      box.kind === 'floor' ? FLOOR_UV_SCALE : 1,
    );
  } else if (box.sz < box.sx) {
    // Z wall: segments along X (length) and Y (height)
    geom = new THREE.BoxGeometry(box.sx, box.sy, box.sz, WALL_SEGMENTS_H, WALL_SEGMENTS_V, 1);
  } else {
    // X wall: segments along Z (length) and Y (height)
    geom = new THREE.BoxGeometry(box.sx, box.sy, box.sz, 1, WALL_SEGMENTS_V, WALL_SEGMENTS_H);
  }
  bakeLightColors(geom, box);
  geom.translate(box.cx, box.cy, box.cz);
  return geom;
}

export class Museum {
  readonly group = new THREE.Group();
  readonly collision = new CollisionWorld();
  readonly paintings: Painting[] = [];
  readonly raycastStatics: THREE.Object3D[] = [];

  constructor(
    paintingTextures: Array<THREE.Texture | null>,
    paintingFileNames: string[],
    paintingImageUrls: string[],
    floorTexture: THREE.Texture | null,
  ) {
    const wallGeoms: THREE.BufferGeometry[] = [];
    const floorGeoms: THREE.BufferGeometry[] = [];
    let paintIdx = 0;

    for (const floor of MUSEUM) {
      for (const room of floor.rooms) {
        const plan = planRoom(room, floor.y);
        for (const box of plan.boxes) {
          (box.kind === 'floor' ? floorGeoms : wallGeoms).push(segmentGeometry(box));
          this.collision.addBox(box.cx, box.cy, box.cz, box.sx, box.sy, box.sz, box.kind === 'floor' ? 'floor' : 'solid');
        }

        // MuseumBuilder._next_painting: sequential assignment, rooms with 3+
        // doors get no painting; when the list runs out, rooms stay bare.
        if (plan.paintingSpot && paintIdx < paintingTextures.length) {
          const tex = paintingTextures[paintIdx];
          const name = paintingFileNames[paintIdx];
          const url = paintingImageUrls[paintIdx];
          paintIdx++;
          if (tex) {
            const painting = new Painting(tex, name, url);
            painting.group.position.set(plan.paintingSpot.x, plan.paintingSpot.y, plan.paintingSpot.z);
            painting.group.rotation.y = plan.paintingSpot.ry;
            this.group.add(painting.group);
            this.paintings.push(painting);
          }
        }
      }
    }

    // Corner patches: diagonal seams between rooms (where a diagonal quadrant
    // has no room) let a 1.1m-wide player drop through the exact grid corner.
    // A 2.2m patch at each corner point that touches a room keeps support
    // across the seam; the patches never extend past the wall lines.
    const patchY = -ROOM_HEIGHT / 2 + WALL_T / 2;
    const patchSize = CAPSULE_RADIUS * 4;
    for (const floor of MUSEUM) {
      const corners = new Set<string>();
      for (const room of floor.rooms) {
        for (const sx of [-5, 5]) {
          for (const sz of [-5, 5]) {
            corners.add(`${room.x + sx},${room.z + sz}`);
          }
        }
      }
      for (const key of corners) {
        const [px, pz] = key.split(',').map(Number);
        const touches = floor.rooms.some(
          (r) => px >= r.x - 5 && px <= r.x + 5 && pz >= r.z - 5 && pz <= r.z + 5,
        );
        if (touches) {
          this.collision.addBox(px, floor.y + patchY, pz, patchSize, WALL_T, patchSize, 'floor');
        }
      }
    }

    const wallMat = new THREE.MeshLambertMaterial({ vertexColors: true });
    wallMat.color.setRGB(
      WALL_COLOR_LINEAR.r,
      WALL_COLOR_LINEAR.g,
      WALL_COLOR_LINEAR.b,
      THREE.LinearSRGBColorSpace,
    );
    if (wallGeoms.length > 0) {
      const wallMesh = new THREE.Mesh(mergeGeometries(wallGeoms, false), wallMat);
      wallMesh.name = 'MuseumWalls';
      this.group.add(wallMesh);
      this.raycastStatics.push(wallMesh);
      wallGeoms.forEach((g) => g.dispose());
    }

    if (floorGeoms.length > 0) {
      const floorMat = new THREE.MeshLambertMaterial({ vertexColors: true });
      if (floorTexture) {
        floorTexture.wrapS = THREE.RepeatWrapping;
        floorTexture.wrapT = THREE.RepeatWrapping;
        floorTexture.colorSpace = THREE.SRGBColorSpace;
        floorMat.map = floorTexture;
        // Lift the dark texture so the baked light pool stays visible
        floorMat.color.setRGB(
          FLOOR_TEXTURE_BOOST,
          FLOOR_TEXTURE_BOOST,
          FLOOR_TEXTURE_BOOST,
          THREE.LinearSRGBColorSpace,
        );
      } else {
        floorMat.color.setRGB(
          DEFAULT_SEGMENT_COLOR_LINEAR.r,
          DEFAULT_SEGMENT_COLOR_LINEAR.g,
          DEFAULT_SEGMENT_COLOR_LINEAR.b,
          THREE.LinearSRGBColorSpace,
        );
      }
      const floorMesh = new THREE.Mesh(mergeGeometries(floorGeoms, false), floorMat);
      floorMesh.name = 'MuseumFloors';
      this.group.add(floorMesh);
      this.raycastStatics.push(floorMesh);
      floorGeoms.forEach((g) => g.dispose());
    }
  }
}
