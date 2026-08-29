// Direct port of MuseumBuilder.gd build() grid.
// Door bits: xp=1, xn=2, zp=4, zn=8. Coordinates are room centers on a 10u grid.
export const DOOR_BIT_XP = 1;
export const DOOR_BIT_XN = 2;
export const DOOR_BIT_ZP = 4;
export const DOOR_BIT_ZN = 8;

export interface RoomDef {
  x: number;
  z: number;
  bits: number;
}

export interface FloorDef {
  name: string;
  y: number;
  rooms: RoomDef[];
}

const r = (x: number, z: number, bits: number): RoomDef => ({ x, z, bits });

// --- Floor 1 ---
const FLOOR_1: RoomDef[] = [
  r(-10, 20, 8),  // (0,1) zn
  r(-20, 10, 1),  // (1,0) xp
  r(-10, 10, 15), // (1,1) all 4
  r(0, 10, 2),    // (1,2) xn
  r(-10, 0, 12),  // (2,1) zp+zn
  r(-10, -10, 13),// (3,1) xp+zp+zn
  r(0, -10, 11),  // (3,2) xp+xn+zn
  r(10, -10, 3),  // (3,3) xp+xn
  r(20, -10, 10), // (3,4) xn+zn
  r(-10, -20, 5), // (4,1) xp+zp
  r(0, -20, 14),  // (4,2) xn+zp+zn
  r(20, -20, 12), // (4,4) zp+zn
  r(0, -30, 5),   // (5,2) xp+zp
  r(10, -30, 3),  // (5,3) xp+xn
  r(20, -30, 6),  // (5,4) xn+zp
];

// --- Floor 2 ---
const FLOOR_2: RoomDef[] = [
  r(-10, 20, 8),  // (0,1) zn
  r(-10, 10, 12), // (1,1) zp+zn
  r(-10, 0, 12),  // (2,1) zp+zn
  r(-10, -10, 12),// (3,1) zp+zn
  r(10, -10, 9),  // (3,3) xp+zn
  r(20, -10, 2),  // (3,4) xn
  r(-10, -20, 5), // (4,1) xp+zp
  r(0, -20, 3),   // (4,2) xp+xn
  r(10, -20, 14), // (4,3) xn+zp+zn
  r(10, -30, 5),  // (5,3) xp+zp
  r(20, -30, 2),  // (5,4) xn
];

// --- Floor 3 ---
const FLOOR_3: RoomDef[] = [
  r(-10, 20, 8),  // (0,1) zn
  r(-10, 10, 12), // (1,1) zp+zn
  r(-10, 0, 13),  // (2,1) xp+zp+zn
  r(0, 0, 3),     // (2,2) xp+xn
  r(10, 0, 2),    // (2,3) xn
  r(-10, -10, 12),// (3,1) zp+zn
  r(-20, -20, 1), // (4,0) xp
  r(-10, -20, 15),// (4,1) xp+xn+zp+zn
  r(0, -20, 3),   // (4,2) xp+xn
  r(10, -20, 2),  // (4,3) xn
  r(-10, -30, 4), // (5,1) zp
];

// --- Floor 4 ---
const FLOOR_4: RoomDef[] = [
  r(-10, 20, 8),  // (0,1) zn
  r(-10, 10, 12), // (1,1) zp+zn
  r(-10, 0, 12),  // (2,1) zp+zn
  r(-10, -10, 12),// (3,1) zp+zn
  r(-10, -20, 4), // (4,1) zp
];

export const MUSEUM: FloorDef[] = [
  { name: '1stFloor', y: 0, rooms: FLOOR_1 },
  { name: '2ndFloor', y: 6, rooms: FLOOR_2 },
  { name: '3rdFloor', y: 12, rooms: FLOOR_3 },
  { name: '4thFloor', y: 18, rooms: FLOOR_4 },
];
