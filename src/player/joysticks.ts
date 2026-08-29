// Port of joystick_movement.gd / joystick_rotation.gd as DOM overlays.
// Touch anywhere on a pad to start dragging; output is the drag vector
// clamped to 40% of the pad size, normalized to -1..1 (Godot behavior).
import type { Vec2Like } from './Player.js';

const PAD_SIZE = 140;
const MAX_DRAG = PAD_SIZE * 0.4;

interface PadState {
  base: HTMLDivElement;
  knob: HTMLDivElement;
  output: Vec2Like;
  pointerId: number;
  startX: number;
  startY: number;
}

export class VirtualJoysticks {
  readonly leftOutput: Vec2Like = { x: 0, y: 0 };
  readonly rightOutput: Vec2Like = { x: 0, y: 0 };
  private pads: PadState[] = [];

  constructor(parent: HTMLElement) {
    this.pads.push(this.createPad('left', this.leftOutput));
    this.pads.push(this.createPad('right', this.rightOutput));
    parent.appendChild(this.root());
  }

  private rootEl: HTMLDivElement | null = null;

  private root(): HTMLDivElement {
    if (!this.rootEl) {
      this.rootEl = document.createElement('div');
      this.rootEl.id = 'joysticks';
    }
    return this.rootEl;
  }

  private createPad(side: 'left' | 'right', output: Vec2Like): PadState {
    const base = document.createElement('div');
    base.className = `joy joy-${side}`;
    const knob = document.createElement('div');
    knob.className = 'joy-knob';
    base.appendChild(knob);

    const state: PadState = { base, knob, output, pointerId: -1, startX: 0, startY: 0 };

    base.addEventListener(
      'pointerdown',
      (e) => {
        if (state.pointerId !== -1) return;
        state.pointerId = e.pointerId;
        state.startX = e.clientX;
        state.startY = e.clientY;
        try {
          base.setPointerCapture(e.pointerId);
        } catch {
          // synthetic pointers (automation) have no active capture target
        }
        e.preventDefault();
      },
      { passive: false },
    );

    base.addEventListener('pointermove', (e) => {
      if (e.pointerId !== state.pointerId) return;
      let dx = e.clientX - state.startX;
      let dy = e.clientY - state.startY;
      const len = Math.hypot(dx, dy);
      if (len > MAX_DRAG) {
        dx = (dx / len) * MAX_DRAG;
        dy = (dy / len) * MAX_DRAG;
      }
      knob.style.transform = `translate(${dx}px, ${dy}px)`;
      output.x = dx / MAX_DRAG;
      output.y = dy / MAX_DRAG;
    });

    const reset = (e: PointerEvent) => {
      if (e.pointerId !== state.pointerId) return;
      state.pointerId = -1;
      knob.style.transform = 'translate(0px, 0px)';
      output.x = 0;
      output.y = 0;
    };
    base.addEventListener('pointerup', reset);
    base.addEventListener('pointercancel', reset);

    this.root().appendChild(base);
    return state;
  }

  dispose(): void {
    this.root().remove();
  }
}
