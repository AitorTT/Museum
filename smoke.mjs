// Headless smoke test: boots the museum, verifies build counts, walks, picks a
// painting via teleport + click, and checks the Android joystick UI.
// Not shipped to prod.
import { chromium } from 'playwright';

const URL = process.env.TEST_URL ?? 'http://localhost:4173/';
const errors = [];

const browser = await chromium.launch({ channel: 'msedge', headless: true });

// ---------- Desktop pass ----------
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on('console', (msg) => {
  if (msg.type() === 'error') errors.push(msg.text());
});
page.on('pageerror', (err) => errors.push(`PAGEERROR: ${err.message}`));

await page.goto(URL, { waitUntil: 'load', timeout: 30000 });
await page.waitForSelector('#enter-btn:not(.hidden)', { timeout: 60000 });
await page.click('#enter-btn');
await page.waitForTimeout(1000);

// Camera height: eye must sit ~1.77m above the feet (Godot rig), not above
// the collision center (which put it at ~2.87m)
const eye = await page.evaluate(() => {
  const p = window.__MUSEUM.player;
  const camY = new (p.position.constructor)(0, 0, 0);
  p.camera.getWorldPosition(camY);
  return { camY: camY.y, feetY: p.position.y - 1.1 };
});
console.log('eye above feet:', (eye.camY - eye.feetY).toFixed(3));
if (Math.abs(eye.camY - eye.feetY - 1.769) > 0.01) {
  throw new Error(`camera eye height wrong: ${eye.camY - eye.feetY}`);
}

const counts = await page.evaluate(() => {
  const m = window.__MUSEUM;
  return { rooms: m.rooms, paintings: m.paintings, colliders: m.colliders };
});
console.log('museum:', JSON.stringify(counts));
if (counts.rooms !== 42) throw new Error(`expected 42 rooms, got ${counts.rooms}`);
if (counts.paintings !== 27) throw new Error(`expected 27 paintings, got ${counts.paintings}`);

// Walk forward through the spawn doorway
await page.keyboard.down('KeyW');
await page.waitForTimeout(800);
await page.keyboard.up('KeyW');
const posAfterWalk = await page.evaluate(() => {
  const p = window.__MUSEUM.player.position;
  return { x: p.x, y: p.y, z: p.z };
});
console.log('pos after walk:', JSON.stringify(posAfterWalk));
if (posAfterWalk.x >= -3.12) throw new Error('player did not move -X while walking');

// Collisions: run at a wall for 3s, position must stop inside the room
await page.keyboard.down('KeyW');
await page.waitForTimeout(3000);
await page.keyboard.up('KeyW');
const posAtWall = await page.evaluate(() => {
  const p = window.__MUSEUM.player.position;
  return { x: p.x, y: p.y, z: p.z };
});
console.log('pos after 3.8s walk:', JSON.stringify(posAtWall));
if (posAtWall.x < -14.8) throw new Error('player clipped through the west wall');

// Painting pick: teleport in front of the first placed painting, aim by
// projecting its world position through the camera, click, expect viewer.
await page.evaluate(() => {
  // First eligible room F1 (-10, 20, bits 8): painting on its zp wall, facing -Z.
  // Pitch slightly up: painting center is now level with the corrected eye height.
  window.__MUSEUM.player.setPose(-10, -1.75, 20, Math.PI, 0.0224);
});
await page.waitForTimeout(300); // let the render loop refresh camera matrices
const aim = await page.evaluate(() => {
  const { museum, player } = window.__MUSEUM;
  const p = museum.paintings[0].group.getWorldPosition(player.position.clone());
  player.camera.updateMatrixWorld(true);
  const v = p.clone().project(player.camera);
  return { painting: { x: p.x, y: p.y, z: p.z }, ndc: { x: v.x, y: v.y } };
});
console.log('aim:', JSON.stringify(aim));
const px = ((aim.ndc.x + 1) / 2) * 1280;
const py = ((1 - aim.ndc.y) / 2) * 720;
if (px < 0 || px > 1280 || py < 0 || py > 720) {
  throw new Error(`painting projects off-screen: ${px.toFixed(0)}, ${py.toFixed(0)}`);
}
await page.screenshot({ path: 'smoke-painting-aim.png' });
await page.mouse.move(px, py);
await page.waitForTimeout(200);
await page.mouse.down();
await page.mouse.up();
await page.waitForTimeout(600);
const viewerOpen = await page.evaluate(
  () => document.getElementById('painting-viewer').style.display !== 'none',
);
console.log('viewer open after painting click:', viewerOpen);
if (!viewerOpen) throw new Error('painting viewer did not open');
await page.screenshot({ path: 'smoke-viewer.png' });

// Second click (still pointer-locked) must close the viewer
await page.mouse.down();
await page.mouse.up();
await page.waitForTimeout(300);
const viewerClosed = await page.evaluate(
  () => document.getElementById('painting-viewer').style.display === 'none',
);
console.log('viewer closed after second click:', viewerClosed);
if (!viewerClosed) throw new Error('second click did not close the painting viewer');

// Elevator: WALK into the car through the room + car doorways (2m wide)
await page.evaluate(() => {
  window.__MUSEUM.player.setPose(23.0, -1.75, -9.97, -Math.PI / 2, 0);
});
await page.keyboard.down('KeyW');
await page.waitForTimeout(1800);
await page.keyboard.up('KeyW');
const enteredX = await page.evaluate(() => window.__MUSEUM.player.position.x);
console.log('x after walking into car:', enteredX);
if (enteredX < 26.3) {
  throw new Error(`could not walk into the elevator: x=${enteredX}`);
}

// Press button 2 and ride to floor 2
await page.evaluate(() => {
  window.__MUSEUM.player.setPose(26.84, -1.75, -9.97, -Math.PI / 2, 0.146);
});
await page.waitForTimeout(400); // let the render loop refresh camera matrices
// One-shot pitch correction from the projected NDC error (fov 50 -> tan(25deg))
const btnAim = await page.evaluate(() => {
  const { elevator, player } = window.__MUSEUM;
  player.camera.updateMatrixWorld(true);
  const v = elevator.interactables[1].pickMeshes[0]
    .getWorldPosition(player.position.clone())
    .project(player.camera);
  const corrected = player.camera.rotation.x + Math.atan(v.y * Math.tan((25 * Math.PI) / 180));
  player.setPose(26.84, -1.75, -9.97, -Math.PI / 2, corrected);
  return { first: { x: v.x, y: v.y }, corrected };
});
await page.waitForTimeout(400);
const btnAim2 = await page.evaluate(() => {
  const { elevator, player } = window.__MUSEUM;
  player.camera.updateMatrixWorld(true);
  const v = elevator.interactables[1].pickMeshes[0]
    .getWorldPosition(player.position.clone())
    .project(player.camera);
  return { x: v.x, y: v.y };
});
console.log('button aim:', JSON.stringify(btnAim), '->', JSON.stringify(btnAim2));
if (Math.abs(btnAim2.x) > 0.2 || Math.abs(btnAim2.y) > 0.2) {
  throw new Error(`elevator button not centered: ${JSON.stringify(btnAim2)}`);
}
await page.mouse.down();
await page.mouse.up();
await page.waitForTimeout(6500); // close 1s + pause 0.4 + move 3 + open 1
const ride = await page.evaluate(() => {
  const p = window.__MUSEUM.player.position;
  return { x: p.x, y: p.y, z: p.z };
});
console.log('pos after elevator ride:', JSON.stringify(ride));
if (Math.abs(ride.y - 4.25) > 0.15) {
  throw new Error(`elevator did not carry player to floor 2: y=${ride.y}`);
}

// Teleporter: step on pad A of pair 1, expect swap to pad B
await page.evaluate(() => {
  window.__MUSEUM.player.setPose(-3.81, -1.75, -13.5, Math.PI);
});
await page.waitForTimeout(400);
const tp = await page.evaluate(() => {
  const p = window.__MUSEUM.player.position;
  return { x: p.x, y: p.y, z: p.z };
});
console.log('pos after teleporter:', JSON.stringify(tp));
if (Math.abs(tp.x - -6.1) > 0.2 || Math.abs(tp.z - -6.5) > 0.2) {
  throw new Error(`teleporter did not swap pads: ${JSON.stringify(tp)}`);
}
if (Math.abs(tp.y - 4.27) > 0.15) {
  throw new Error(`teleporter landed at wrong height: ${tp.y}`);
}

// Collision solidity: in-building drop must land on the floor below (no
// tunneling, no respawn), and a void fall must respawn at the spawn point.
await page.evaluate(() => {
  // Just under floor 2's slab inside room (-10,20) F1
  window.__MUSEUM.player.setPose(-10, 1.89, 20, Math.PI);
});
await page.waitForTimeout(1500);
const drop = await page.evaluate(() => {
  const p = window.__MUSEUM.player.position;
  return { x: p.x, y: p.y, z: p.z };
});
console.log('in-building drop landed:', JSON.stringify(drop));
if (Math.abs(drop.x - -10) > 0.05 || Math.abs(drop.y - -1.75) > 0.05) {
  throw new Error(`drop tunneled or respawned: ${JSON.stringify(drop)}`);
}

await page.evaluate(() => {
  // Void outside the building footprint
  window.__MUSEUM.player.setPose(-25, 5, 20, Math.PI);
});
await page.waitForTimeout(2600);
const voidFall = await page.evaluate(() => {
  const p = window.__MUSEUM.player.position;
  return { x: p.x, y: p.y, z: p.z };
});
console.log('void fall respawned to:', JSON.stringify(voidFall));
if (Math.abs(voidFall.x - -3.129) > 0.05 || Math.abs(voidFall.z - -8.9) > 0.05) {
  throw new Error(`void fall did not respawn cleanly: ${JSON.stringify(voidFall)}`);
}

await page.close();

// ---------- Android pass ----------
const ctx = await browser.newContext({
  userAgent:
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  viewport: { width: 390, height: 844 },
  hasTouch: true,
  isMobile: true,
});
const mpage = await ctx.newPage();
mpage.on('pageerror', (err) => errors.push(`MOBILE PAGEERROR: ${err.message}`));

await mpage.goto(URL, { waitUntil: 'load', timeout: 30000 });
await mpage.waitForSelector('#enter-btn:not(.hidden)', { timeout: 60000 });
await mpage.tap('#enter-btn');
await mpage.waitForTimeout(800);

const joys = await mpage.evaluate(() => document.querySelectorAll('.joy').length);
console.log('joysticks visible on android:', joys);
if (joys !== 2) throw new Error(`expected 2 joysticks on android, got ${joys}`);

// Drag left joystick up (forward), drag right joystick left (turn)
const left = await mpage.locator('.joy-left').boundingBox();
const right = await mpage.locator('.joy-right').boundingBox();
await mpage.touchscreen.tap(10, 10); // no-op tap (empty space)
const posBefore = await mpage.evaluate(() => {
  const p = window.__MUSEUM.player.position;
  return { x: p.x, z: p.z };
});
// swipe left pad upward
await mpage.touchscreen.tap(left.x + left.width / 2, left.y + left.height / 2);
// use mouse-drag emulation via dispatching pointer events on the pad
await mpage.evaluate(() => {
  const pad = document.querySelector('.joy-left');
  const knobStart = (type, x, y) =>
    pad.dispatchEvent(
      new PointerEvent(type, { pointerId: 7, clientX: x, clientY: y, bubbles: true }),
    );
  knobStart('pointerdown', 200, 700);
  for (let i = 1; i <= 10; i++) knobStart('pointermove', 200, 700 - i * 6);
});
await mpage.waitForTimeout(1000);
await mpage.evaluate(() => {
  const pad = document.querySelector('.joy-left');
  pad.dispatchEvent(
    new PointerEvent('pointerup', { pointerId: 7, clientX: 200, clientY: 640, bubbles: true }),
  );
});
const posAfter = await mpage.evaluate(() => {
  const p = window.__MUSEUM.player.position;
  return { x: p.x, z: p.z };
});
console.log('mobile pos before/after joystick push:', JSON.stringify(posBefore), JSON.stringify(posAfter));
const moved = Math.hypot(posAfter.x - posBefore.x, posAfter.z - posBefore.z);
if (moved < 0.5) throw new Error(`joystick did not move the player (${moved})`);

await mpage.screenshot({ path: 'smoke-android.png' });
await ctx.close();

await browser.close();
if (errors.length > 0) {
  console.log('console errors:', errors);
  process.exit(1);
}
console.log('SMOKE OK');
