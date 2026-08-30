// Stress: random walk, elevator up/down rides, repeated teleports.
// Asserts invariants: never below floor, never out of bounds, rides land exactly.
import { chromium } from 'playwright';

const URL = 'http://localhost:4173/';
const errors = [];
const browser = await chromium.launch({ channel: 'msedge', headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on('pageerror', (e) => errors.push(e.message));

await page.goto(URL, { waitUntil: 'load' });
await page.waitForSelector('#enter-btn:not(.hidden)', { timeout: 60000 });
await page.click('#enter-btn');
await page.waitForTimeout(500);

// ---- Phase 1: random walk (12s) — may leave rooms through doors (by design,
// some open onto the void); the invariant is: always recovered onto a walkable
// floor level (or mid-respawn), never stuck below the world.
await page.evaluate(() => {
  (globalThis).__COLTRACE = [];
  window.__MUSEUM.player.setPose(-3.13, -1.75, -8.9, 0);
});
await page.keyboard.down('KeyW');
let voidFalls = 0;
let lastY = -1.75;
let fellAt = null;
for (let i = 0; i < 24; i++) {
  await page.evaluate((yaw) => {
    const p = window.__MUSEUM.player.position;
    window.__MUSEUM.player.setPose(p.x, p.y, p.z, yaw, 0);
  }, Math.random() * Math.PI * 2);
  await page.waitForTimeout(500);
  const s = await page.evaluate(() => {
    const p = window.__MUSEUM.player.position;
    return { x: p.x, y: p.y, z: p.z };
  });
  if (lastY > -3 && s.y < -3 && s.y > -30) voidFalls++;
  if (s.y < -3 && !fellAt) fellAt = { x: +s.x.toFixed(2), y: +s.y.toFixed(2), z: +s.z.toFixed(2) };
  if (s.y < -39) {
    console.log('FALL SPOT:', JSON.stringify(fellAt), 'now:', JSON.stringify(s));
    throw new Error('fell below the world');
  }
  lastY = s.y;
}
await page.keyboard.up('KeyW');
const walkEnd = await page.evaluate(() => {
  const p = window.__MUSEUM.player.position;
  return { x: p.x, y: p.y, z: p.z, vy: window.__MUSEUM.player.velocity.y };
});
console.log('random walk end:', JSON.stringify(walkEnd), 'voidFalls:', voidFalls);
if (voidFalls !== 0) {
  console.log('FALL SPOT:', JSON.stringify(fellAt));
  throw new Error(`void falls still happening: ${voidFalls}`);
}
const floorLevels = [-1.75, 4.25, 10.25, 16.25];
const onAFloor = floorLevels.some((l) => Math.abs(walkEnd.y - l) < 0.2);
if (!onAFloor && walkEnd.vy !== 0) throw new Error('ended embedded/below a floor');

// ---- Phase 2: elevator up + DOWN ride ----
await page.evaluate(() => window.__MUSEUM.player.setPose(23.0, -1.75, -9.97, -Math.PI / 2, 0));
await page.keyboard.down('KeyW');
await page.waitForTimeout(1500);
await page.keyboard.up('KeyW');
const inCar = await page.evaluate(() => window.__MUSEUM.player.position.x);
console.log('walked into car:', inCar.toFixed(2));
if (inCar < 26.0) throw new Error('failed to walk into car');

await page.evaluate(() => window.__MUSEUM.player.setPose(26.84, -1.75, -9.97, 0.474, 0.146));
await page.waitForTimeout(400);
// press 2 (aim adaptive)
await page.evaluate(() => {
  const { elevator, player } = window.__MUSEUM;
  player.camera.updateMatrixWorld(true);
  const v = elevator.interactables[1].pickMeshes[0]
    .getWorldPosition(player.position.clone())
    .project(player.camera);
  const corrected = player.camera.rotation.x + Math.atan(v.y * Math.tan((25 * Math.PI) / 180));
  player.setPose(26.84, -1.75, -9.97, 0.474, corrected);
});
await page.waitForTimeout(400);
await page.mouse.down();
await page.mouse.up();
await page.waitForTimeout(6500);
const up = await page.evaluate(() => window.__MUSEUM.player.position.y);
console.log('after up ride:', up.toFixed(3));
if (Math.abs(up - 4.25) > 0.15) throw new Error(`up ride failed: y=${up}`);

// press 1 (button index 0) to ride DOWN
await page.evaluate(() => {
  const { elevator, player } = window.__MUSEUM;
  player.camera.updateMatrixWorld(true);
  const v = elevator.interactables[0].pickMeshes[0]
    .getWorldPosition(player.position.clone())
    .project(player.camera);
  const corrected = player.camera.rotation.x + Math.atan(v.y * Math.tan((25 * Math.PI) / 180));
  player.setPose(26.84, 4.2501, -9.97, 0.474, corrected);
});
await page.waitForTimeout(400);
await page.mouse.down();
await page.mouse.up();
await page.waitForTimeout(6500);
const down = await page.evaluate(() => {
  const p = window.__MUSEUM.player.position;
  return { x: p.x, y: p.y, z: p.z };
});
console.log('after down ride:', JSON.stringify(down));
if (Math.abs(down.y - -1.75) > 0.15) throw new Error(`down ride failed: y=${down.y}`);

// ---- Phase 3: teleports (edge-triggered: step off, then back on) ----
for (let i = 0; i < 2; i++) {
  await page.evaluate(() => window.__MUSEUM.player.setPose(-3.81, -1.75, -13.5, Math.PI));
  await page.waitForTimeout(1400); // teleport + settle
  const tp = await page.evaluate(() => {
    const p = window.__MUSEUM.player.position;
    return { x: p.x, y: p.y };
  });
  console.log(`teleport ${i + 1}:`, JSON.stringify(tp));
  if (Math.abs(tp.x - -6.1) > 0.2) throw new Error(`teleport ${i + 1} failed`);
  // step off the pad so the next entry re-arms
  await page.evaluate(() => window.__MUSEUM.player.setPose(-1.0, -1.75, -13.5, Math.PI));
  await page.waitForTimeout(300);
}

const finalCheck = await page.evaluate(() => {
  const p = window.__MUSEUM.player.position;
  return { y: p.y, inWorld: p.y > -40 };
});
console.log('final:', JSON.stringify(finalCheck));

await browser.close();
if (errors.length) {
  console.log(errors);
  process.exit(1);
}
console.log('STRESS OK');
