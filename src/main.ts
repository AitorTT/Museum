import * as THREE from 'three';
import {
  AMBIENT_INTENSITY,
  SKY_COLOR,
  PAINTINGS_DIR,
  FLOOR_TEXTURE,
} from './config.js';
import { Museum } from './museum/Museum.js';
import { MUSEUM } from './museum/layout.js';
import { createSky } from './museum/Sky.js';
import { Elevator } from './museum/Elevator.js';
import { Teleporters } from './museum/Teleporters.js';
import type { Interactable } from './interaction/Interactable.js';
import { PAINTING_FILES, paintingUrl } from './museum/paintingList.js';
import { Player } from './player/Player.js';
import { VirtualJoysticks } from './player/joysticks.js';
import { Interaction } from './interaction/raycast.js';
import { PaintingViewer } from './ui/PaintingViewer.js';

const isMobile =
  /Android/i.test(navigator.userAgent) ||
  new URLSearchParams(location.search).has('mobile');

const loadFill = document.getElementById('load-fill') as HTMLDivElement;
const loadText = document.getElementById('load-text') as HTMLDivElement;
const loadWrap = document.getElementById('load-wrap') as HTMLDivElement;
const overlay = document.getElementById('overlay') as HTMLDivElement;
const enterBtn = document.getElementById('enter-btn') as HTMLButtonElement;
const crosshair = document.getElementById('crosshair') as HTMLDivElement;

let started = false;
let player: Player;
let renderer: THREE.WebGLRenderer;
let scene: THREE.Scene;

function loadTexture(
  manager: THREE.LoadingManager,
  url: string,
): Promise<THREE.Texture | null> {
  return new Promise((resolve) => {
    new THREE.TextureLoader(manager).load(
      url,
      (tex) => resolve(tex),
      undefined,
      () => resolve(null),
    );
  });
}

function main(): void {
  const manager = new THREE.LoadingManager();
  manager.onProgress = (_url, loaded, total) => {
    const pct = Math.round((loaded / total) * 100);
    loadFill.style.width = `${pct}%`;
    loadText.textContent = `Loading ${pct}%`;
  };

  const floorPromise = loadTexture(manager, FLOOR_TEXTURE);
  const paintingPromises = PAINTING_FILES.map((f) =>
    loadTexture(manager, paintingUrl(PAINTINGS_DIR, f)),
  );
  const urls = PAINTING_FILES.map((f) => paintingUrl(PAINTINGS_DIR, f));

  Promise.all([floorPromise, ...paintingPromises]).then(([floorTex, ...paintingTextures]) => {
    loadWrap.classList.add('hidden');
    enterBtn.classList.remove('hidden');
    enterBtn.textContent = isMobile ? 'TAP TO ENTER' : 'ENTER';
    enterBtn.addEventListener('click', () => enter());
    setupScene(floorTex, paintingTextures as Array<THREE.Texture | null>, urls);
  });
}

function setupScene(
  floorTex: THREE.Texture | null,
  paintingTextures: Array<THREE.Texture | null>,
  paintingUrls: string[],
): void {
  renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(window.innerWidth, window.innerHeight);
  document.body.appendChild(renderer.domElement);

  scene = new THREE.Scene();
  scene.background = new THREE.Color(SKY_COLOR);

  const ambient = new THREE.AmbientLight(0xffffff, AMBIENT_INTENSITY);
  scene.add(ambient);

  const museum = new Museum(paintingTextures, PAINTING_FILES, paintingUrls, floorTex);
  scene.add(museum.group);

  scene.add(createSky());

  const elevator = new Elevator();
  scene.add(elevator.group);
  museum.collision.dynamicBoxes = elevator.dynamicBoxes;

  const teleporters = new Teleporters();
  scene.add(teleporters.group);

  player = new Player(museum.collision);
  scene.add(player.yawObject);

  // Debug/testing handle (harmless in production)
  (window as unknown as Record<string, unknown>).__MUSEUM = {
    paintings: museum.paintings.length,
    colliders: museum.collision.boxes.length,
    rooms: MUSEUM.reduce((n, f) => n + f.rooms.length, 0),
    layout: MUSEUM,
    museum,
    player,
    elevator,
    teleporters,
  };

  if (isMobile) {
    const joysticks = new VirtualJoysticks(document.body);
    player.moveInput = joysticks.leftOutput;
    player.joystickLook = joysticks.rightOutput;
  }

  const viewer = new PaintingViewer();
  const paintingInteractables: Interactable[] = museum.paintings.map((p) => ({
    pickMeshes: p.pickMeshes,
    onHover: () => p.onHoverEnter(),
    onUnhover: () => p.onHoverExit(),
    onClick: () => viewer.show(p.imageUrl, p.fileName),
  }));
  new Interaction(
    player.camera,
    [...paintingInteractables, ...elevator.interactables],
    museum.raycastStatics,
    viewer,
    renderer.domElement,
    isMobile,
  );

  // Correct the camera aspect immediately (it defaults to 1 and would stretch
  // the image until the first real resize event).
  const resize = () => {
    player.camera.aspect = window.innerWidth / window.innerHeight;
    player.camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
  };
  resize();
  window.addEventListener('resize', resize);

  if (!isMobile) {
    renderer.domElement.addEventListener('mousemove', (e) => {
      player.onMouseMove(e.movementX, e.movementY);
    });
    document.addEventListener('pointerlockchange', () => {
      const locked = document.pointerLockElement === renderer.domElement;
      if (!locked && started) {
        enterBtn.textContent = 'CLICK TO RESUME';
        overlay.classList.remove('hidden');
        crosshair.classList.add('hidden');
      }
    });
  }

  let lastTime = performance.now();
  renderer.setAnimationLoop(() => {
    const now = performance.now();
    const dt = Math.min((now - lastTime) / 1000, 0.05);
    lastTime = now;
    elevator.update(dt, player.position);
    teleporters.update(dt, player);
    player.update(dt);
    renderer.render(scene, player.camera);
  });
}

const keys = new Set<string>();
function updateKeyInput(): void {
  if (!player) return;
  player.moveInput.x = (keys.has('KeyD') ? 1 : 0) - (keys.has('KeyA') ? 1 : 0);
  player.moveInput.y = (keys.has('KeyS') ? 1 : 0) - (keys.has('KeyW') ? 1 : 0);
}
window.addEventListener('keydown', (e) => {
  keys.add(e.code);
  if (e.code === 'KeyW' || e.code === 'KeyA' || e.code === 'KeyS' || e.code === 'KeyD') {
    e.preventDefault();
  }
  updateKeyInput();
});
window.addEventListener('keyup', (e) => {
  keys.delete(e.code);
  updateKeyInput();
});

function enter(): void {
  started = true;
  overlay.classList.add('hidden');
  crosshair.classList.toggle('hidden', isMobile);
  if (!isMobile) {
    renderer.domElement.requestPointerLock();
  }
}

window.addEventListener('contextmenu', (e) => e.preventDefault());

main();
