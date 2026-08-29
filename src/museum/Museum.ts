// Builds the whole museum: merged static geometry, colliders, and paintings.
import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import {
  WALL_COLOR_LINEAR,
  DEFAULT_SEGMENT_COLOR_LINEAR,
  FLOOR_UV_SCALE,
} from '../config.js';
import { MUSEUM } from './layout.js';
import { planRoom, type SegmentBox } from './RoomBuilder.js';
import { Painting } from './Painting.js';
import { CollisionWorld } from '../player/Colliders.js';

// Repeats the floor texture per world unit (approximates Godot's triplanar uv1_scale=2)
function boxWithTiledUVs(sx: number, sy: number, sz: number, uvScale: number): THREE.BoxGeometry {
  const geom = new THREE.BoxGeometry(sx, sy, sz);
  const uv = geom.attributes.uv as THREE.BufferAttribute;
  // BoxGeometry face order: +x, -x, +y, -y, +z, -z (4 verts each)
  const dims: Array<[number, number]> = [
    [sz, sy],
    [sz, sy],
    [sx, sz],
    [sx, sz],
    [sx, sy],
    [sx, sy],
  ];
  for (let face = 0; face < 6; face++) {
    const [du, dv] = dims[face];
    for (let i = face * 4; i < face * 4 + 4; i++) {
      uv.setXY(i, uv.getX(i) * du * uvScale, uv.getY(i) * dv * uvScale);
    }
  }
  return geom;
}

function segmentGeometry(box: SegmentBox): THREE.BufferGeometry {
  let geom: THREE.BoxGeometry;
  if (box.kind === 'floor') {
    geom = boxWithTiledUVs(box.sx, box.sy, box.sz, FLOOR_UV_SCALE);
  } else {
    geom = new THREE.BoxGeometry(box.sx, box.sy, box.sz);
  }
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
          this.collision.addBox(box.cx, box.cy, box.cz, box.sx, box.sy, box.sz);
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

    const wallMat = new THREE.MeshLambertMaterial();
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
      const floorMat = new THREE.MeshLambertMaterial();
      if (floorTexture) {
        floorTexture.wrapS = THREE.RepeatWrapping;
        floorTexture.wrapT = THREE.RepeatWrapping;
        floorTexture.colorSpace = THREE.SRGBColorSpace;
        floorMat.map = floorTexture;
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
