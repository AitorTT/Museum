// Port of RoomBuilder.gd wall segmentation + MuseumBuilder.gd room planning.
// All geometry is axis-aligned boxes; every solid segment doubles as a collider.
import {
  ROOM_WIDTH,
  ROOM_HEIGHT,
  ROOM_DEPTH,
  WALL_T,
  DOOR_WIDTH,
  DOOR_HEIGHT,
  WINDOW_WIDTH,
  WINDOW_HEIGHT,
  WINDOW_BOTTOM,
  PAINTING_HEIGHT,
} from '../config.js';
import {
  DOOR_BIT_XP,
  DOOR_BIT_XN,
  DOOR_BIT_ZP,
  DOOR_BIT_ZN,
  type RoomDef,
} from './layout.js';

export type SegmentKind = 'wall' | 'floor';

export interface SegmentBox {
  cx: number;
  cy: number;
  cz: number;
  sx: number;
  sy: number;
  sz: number;
  kind: SegmentKind;
}

export interface PaintingSpot {
  x: number;
  y: number;
  z: number;
  ry: number;
}

export interface RoomPlan {
  boxes: SegmentBox[];
  paintingSpot: PaintingSpot | null;
}

const HW = ROOM_WIDTH / 2;
const HD = ROOM_DEPTH / 2;
const HH = ROOM_HEIGHT / 2;

// painting placement offsets (RoomBuilder._add_room_features)
const FACE_INSET = WALL_T + 0.02;

export function planRoom(room: RoomDef, floorY: number): RoomPlan {
  const boxes: SegmentBox[] = [];
  const seg = (
    lx: number,
    ly: number,
    lz: number,
    sx: number,
    sy: number,
    sz: number,
    kind: SegmentKind = 'wall',
  ) => {
    boxes.push({
      cx: lx + room.x,
      cy: ly + floorY,
      cz: lz + room.z,
      sx,
      sy,
      sz,
      kind,
    });
  };

  const doorXP = (room.bits & DOOR_BIT_XP) !== 0;
  const doorXN = (room.bits & DOOR_BIT_XN) !== 0;
  const doorZP = (room.bits & DOOR_BIT_ZP) !== 0;
  const doorZN = (room.bits & DOOR_BIT_ZN) !== 0;

  // MuseumBuilder._room: window + painting assignment on door-free walls
  const doorCount = doorXP ? 1 : 0 + (doorXN ? 1 : 0) + (doorZP ? 1 : 0) + (doorZN ? 1 : 0);
  const paintings = doorCount < 3 ? 1 : 0;
  const walls = ['xp', 'xn', 'zp', 'zn'] as const;
  const isDoor: Record<string, boolean> = { xp: doorXP, xn: doorXN, zp: doorZP, zn: doorZN };
  const free = walls.filter((w) => !isDoor[w]);
  const windowWalls = new Set(free.slice(0, Math.max(0, free.length - paintings)));
  const paintingWall = paintings > 0 && free.length > 0 ? free[free.length - paintings] : null;

  // Walls (RoomBuilder._build_room_contents)
  zWall(seg, 0, 0, -HD + WALL_T * 0.5, ROOM_WIDTH + WALL_T * 2, doorZN, windowWalls.has('zn'));
  zWall(seg, 0, 0, HD - WALL_T * 0.5, ROOM_WIDTH + WALL_T * 2, doorZP, windowWalls.has('zp'));
  xWall(seg, -HW + WALL_T * 0.5, 0, 0, ROOM_DEPTH, doorXN, windowWalls.has('xn'));
  xWall(seg, HW - WALL_T * 0.5, 0, 0, ROOM_DEPTH, doorXP, windowWalls.has('xp'));

  // Floor + ceiling
  seg(0, -HH + WALL_T * 0.5, 0, ROOM_WIDTH, WALL_T, ROOM_DEPTH, 'floor');
  seg(0, HH - WALL_T * 0.5, 0, ROOM_WIDTH, WALL_T, ROOM_DEPTH, 'wall');

  // Painting spot (RoomBuilder._add_room_features; offsets h/v are 0 in the museum build)
  const py = -HH + PAINTING_HEIGHT;
  let paintingSpot: PaintingSpot | null = null;
  if (paintingWall === 'xp') {
    paintingSpot = { x: room.x + HW - FACE_INSET, y: floorY + py, z: room.z, ry: -Math.PI / 2 };
  } else if (paintingWall === 'xn') {
    paintingSpot = { x: room.x - HW + FACE_INSET, y: floorY + py, z: room.z, ry: Math.PI / 2 };
  } else if (paintingWall === 'zp') {
    paintingSpot = { x: room.x, y: floorY + py, z: room.z + HD - FACE_INSET, ry: Math.PI };
  } else if (paintingWall === 'zn') {
    paintingSpot = { x: room.x, y: floorY + py, z: room.z - HD + FACE_INSET, ry: 0 };
  }

  return { boxes, paintingSpot };
}

// Port of RoomBuilder._add_z_wall (front/back walls; segments span X, thickness on Z)
function zWall(
  seg: (lx: number, ly: number, lz: number, sx: number, sy: number, sz: number, kind?: SegmentKind) => void,
  lx: number,
  ly: number,
  lz: number,
  fw: number,
  hasDoor: boolean,
  hasWindow: boolean,
): void {
  const fh = ROOM_HEIGHT;
  const t = WALL_T;

  if (hasDoor) {
    const dw = Math.min(DOOR_WIDTH, fw - 0.2);
    const dh = Math.min(DOOR_HEIGHT, fh - 0.1);
    const lw = (fw - dw) * 0.5;
    const th = fh - dh;
    if (lw > 0.01) {
      seg(lx - (fw - lw) * 0.5, ly, lz, lw, fh, t);
      seg(lx + (fw - lw) * 0.5, ly, lz, lw, fh, t);
    }
    if (th > 0.01) {
      seg(lx, ly + (fh - th) * 0.5, lz, dw, th, t);
    }
    return; // door filler is invisible + non-colliding in Godot: skipped
  }

  if (hasWindow) {
    const ww = Math.min(WINDOW_WIDTH, fw - 0.2);
    const wh = Math.min(WINDOW_HEIGHT, fh - 0.1);
    const wcy = -fh * 0.5 + WINDOW_BOTTOM + wh * 0.5;
    const lw = (fw - ww) * 0.5;
    const th = fh * 0.5 - (wcy + wh * 0.5);
    const bh = wcy - wh * 0.5 - -fh * 0.5;
    if (lw > 0.01) {
      seg(lx - (fw - lw) * 0.5, ly, lz, lw, fh, t);
      seg(lx + (fw - lw) * 0.5, ly, lz, lw, fh, t);
    }
    if (th > 0.01) {
      const cy = (fh * 0.5 + wcy + wh * 0.5) * 0.5;
      seg(lx, ly + cy, lz, ww, th, t);
    }
    if (bh > 0.01) {
      const cy = (-fh * 0.5 + wcy - wh * 0.5) * 0.5;
      seg(lx, ly + cy, lz, ww, bh, t);
    }
    return;
  }

  seg(lx, ly, lz, fw, fh, t);
}

// Port of RoomBuilder._add_x_wall (left/right walls; thickness on X)
function xWall(
  seg: (lx: number, ly: number, lz: number, sx: number, sy: number, sz: number, kind?: SegmentKind) => void,
  lx: number,
  ly: number,
  lz: number,
  fw: number,
  hasDoor: boolean,
  hasWindow: boolean,
): void {
  const fh = ROOM_HEIGHT;
  const t = WALL_T;

  if (hasDoor) {
    const dw = Math.min(DOOR_WIDTH, fw - 0.2);
    const dh = Math.min(DOOR_HEIGHT, fh - 0.1);
    const lw = (fw - dw) * 0.5;
    const th = fh - dh;
    if (lw > 0.01) {
      seg(lx, ly, lz - (fw - lw) * 0.5, t, fh, lw);
      seg(lx, ly, lz + (fw - lw) * 0.5, t, fh, lw);
    }
    if (th > 0.01) {
      seg(lx, ly + (fh - th) * 0.5, lz, t, th, dw);
    }
    return;
  }

  if (hasWindow) {
    const ww = Math.min(WINDOW_WIDTH, fw - 0.2);
    const wh = Math.min(WINDOW_HEIGHT, fh - 0.1);
    const wcy = -fh * 0.5 + WINDOW_BOTTOM + wh * 0.5;
    const lw = (fw - ww) * 0.5;
    const th = fh * 0.5 - (wcy + wh * 0.5);
    const bh = wcy - wh * 0.5 - -fh * 0.5;
    if (lw > 0.01) {
      seg(lx, ly, lz - (fw - lw) * 0.5, t, fh, lw);
      seg(lx, ly, lz + (fw - lw) * 0.5, t, fh, lw);
    }
    if (th > 0.01) {
      const cy = (fh * 0.5 + wcy + wh * 0.5) * 0.5;
      seg(lx, ly + cy, lz, t, th, ww);
    }
    if (bh > 0.01) {
      const cy = (-fh * 0.5 + wcy - wh * 0.5) * 0.5;
      seg(lx, ly + cy, lz, t, bh, ww);
    }
    return;
  }

  seg(lx, ly, lz, t, fh, fw);
}
