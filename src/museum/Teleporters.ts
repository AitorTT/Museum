// Port of Teleporter.gd: pairs of floor pads that swap the player between
// them, with a per-pair cooldown. Pads get a Minecraft-nether-portal style
// animated swirl surface plus rising particles.
import * as THREE from 'three';
import {
  TELEPORT_PAIRS,
  TELEPORT_RADIUS,
  TELEPORT_COOLDOWN,
  floorTopY,
  CAPSULE_HEIGHT,
} from '../config.js';
import type { Player } from '../player/Player.js';

const PORTAL_VERT = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const PORTAL_FRAG = /* glsl */ `
  uniform float uTime;
  varying vec2 vUv;
  void main() {
    vec2 p = vUv * 2.0 - 1.0;
    float r = length(p);
    if (r > 1.0) discard;
    float a = atan(p.y, p.x);
    float swirl = sin(a * 3.0 + uTime * 2.2 - r * 10.0);
    float shimmer = sin(a * 5.0 - uTime * 1.4 + r * 6.0);
    vec3 deep = vec3(0.23, 0.05, 0.45);
    vec3 mid = vec3(0.55, 0.15, 0.85);
    vec3 glow = vec3(0.78, 0.45, 1.0);
    vec3 col = mix(deep, mid, 0.5 + 0.5 * swirl);
    col = mix(col, glow, max(0.0, shimmer) * 0.6);
    float edge = smoothstep(1.0, 0.55, r);
    float alpha = edge * (0.55 + 0.35 * swirl);
    gl_FragColor = vec4(col * 1.5, alpha);
    #include <colorspace_fragment>
  }
`;

const PARTICLES_PER_PAD = 24;

interface Pad {
  x: number;
  z: number;
  topY: number;
  swirlMat: THREE.ShaderMaterial;
  points: THREE.Points;
  geo: THREE.BufferGeometry;
  state: Array<{ angle: number; radius: number; y: number; speed: number }>;
}

interface Pair {
  a: Pad;
  b: Pad;
  cooldown: number;
  playerOn: boolean;
}

export class Teleporters {
  readonly group = new THREE.Group();
  private pairs: Pair[] = [];
  private time = 0;

  constructor() {
    const padGeo = new THREE.CylinderGeometry(1, 1, 0.06, 24);
    const rimGeo = new THREE.CylinderGeometry(1.12, 1.12, 0.04, 24);
    const padMat = new THREE.MeshBasicMaterial({ color: 0x2a1a4a });
    const rimMat = new THREE.MeshBasicMaterial({ color: 0x4a2a7a });
    const swirlGeo = new THREE.CircleGeometry(0.95, 40);

    for (const [defA, defB] of TELEPORT_PAIRS) {
      const a = this.addPad(defA, padGeo, rimGeo, swirlGeo, padMat, rimMat);
      const b = this.addPad(defB, padGeo, rimGeo, swirlGeo, padMat, rimMat);
      this.pairs.push({ a, b, cooldown: 0, playerOn: false });
    }
  }

  private addPad(
    def: { x: number; z: number; floor: number },
    padGeo: THREE.CylinderGeometry,
    rimGeo: THREE.CylinderGeometry,
    swirlGeo: THREE.CircleGeometry,
    padMat: THREE.MeshBasicMaterial,
    rimMat: THREE.MeshBasicMaterial,
  ): Pad {
    const topY = floorTopY(def.floor) + 0.03;
    const group = new THREE.Group();
    group.position.set(def.x, topY, def.z);

    const rim = new THREE.Mesh(rimGeo, rimMat);
    this.group.add(rim);
    rim.position.set(def.x, floorTopY(def.floor) + 0.02, def.z);

    const pad = new THREE.Mesh(padGeo, padMat);
    group.add(pad);

    // Animated swirl surface hovering just above the pad
    const swirlMat = new THREE.ShaderMaterial({
      uniforms: { uTime: { value: 0 } },
      vertexShader: PORTAL_VERT,
      fragmentShader: PORTAL_FRAG,
      transparent: true,
      depthWrite: false,
      side: THREE.DoubleSide,
      blending: THREE.AdditiveBlending,
    });
    const swirl = new THREE.Mesh(swirlGeo, swirlMat);
    swirl.rotation.x = -Math.PI / 2; // lay flat, facing up
    swirl.position.y = 0.07;
    group.add(swirl);

    // Rising particles
    const state: Array<{ angle: number; radius: number; y: number; speed: number }> = [];
    const positions = new Float32Array(PARTICLES_PER_PAD * 3);
    for (let i = 0; i < PARTICLES_PER_PAD; i++) {
      state.push({
        angle: Math.random() * Math.PI * 2,
        radius: 0.15 + Math.random() * 0.65,
        y: Math.random() * 1.6,
        speed: 0.25 + Math.random() * 0.45,
      });
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    const points = new THREE.Points(
      geo,
      new THREE.PointsMaterial({
        color: 0xc084fc,
        size: 0.07,
        transparent: true,
        opacity: 0.9,
        blending: THREE.AdditiveBlending,
        depthWrite: false,
        sizeAttenuation: true,
      }),
    );
    group.add(points);

    this.group.add(group);
    return { x: def.x, z: def.z, topY, swirlMat, points, geo, state };
  }

  update(dt: number, player: Player): void {
    this.time += dt;

    for (const pair of this.pairs) {
      if (pair.cooldown > 0) {
        pair.cooldown -= dt;
      }
      for (const pad of [pair.a, pair.b]) {
        pad.swirlMat.uniforms.uTime.value = this.time;
        const attr = pad.geo.attributes.position as THREE.BufferAttribute;
        for (let i = 0; i < pad.state.length; i++) {
          const s = pad.state[i];
          s.y += s.speed * dt;
          s.angle += 0.9 * dt;
          if (s.y > 1.7) s.y = 0;
          attr.setXYZ(
            i,
            Math.cos(s.angle) * s.radius * (1 - s.y / 1.9),
            s.y + 0.08,
            Math.sin(s.angle) * s.radius * (1 - s.y / 1.9),
          );
        }
        attr.needsUpdate = true;
      }

      // Edge-triggered like Godot's Area3D body_entered: teleport once on
      // entry; standing still on the destination pad must not bounce back.
      const onA = this.onPad(pair.a, player);
      const onB = this.onPad(pair.b, player);
      const entering = (onA || onB) && !pair.playerOn && pair.cooldown <= 0;
      if (entering) {
        const target = onA ? pair.b : pair.a;
        player.teleportTo(target.x, target.topY + CAPSULE_HEIGHT / 2 + 0.02, target.z);
        pair.cooldown = TELEPORT_COOLDOWN;
      }
      pair.playerOn = onA || onB;
    }
  }

  private onPad(pad: Pad, player: Player): boolean {
    const dx = player.position.x - pad.x;
    const dz = player.position.z - pad.z;
    if (dx * dx + dz * dz > TELEPORT_RADIUS * TELEPORT_RADIUS) return false;
    const feetY = player.position.y - CAPSULE_HEIGHT / 2;
    return Math.abs(feetY - pad.topY) <= 0.6;
  }
}
