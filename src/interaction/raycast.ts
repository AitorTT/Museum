// Port of character_body_3d.gd _unhandled_input picking, generalized to any
// Interactable (paintings, elevator buttons, ...).
// Desktop: hover from mouse position (screen-center ray while pointer-locked,
// matching Godot's captured-mouse behavior); touch taps click directly.
import * as THREE from 'three';
import type { Interactable } from './Interactable.js';
import type { PaintingViewer } from '../ui/PaintingViewer.js';

export class Interaction {
  private raycaster = new THREE.Raycaster();
  private hovered: Interactable | null = null;
  private ndc = new THREE.Vector2();
  private meshMap = new Map<THREE.Object3D, Interactable>();

  constructor(
    private camera: THREE.Camera,
    interactables: Interactable[],
    private statics: THREE.Object3D[],
    private viewer: PaintingViewer,
    private canvas: HTMLCanvasElement,
    isMobile: boolean,
  ) {
    for (const entry of interactables) {
      for (const mesh of entry.pickMeshes) {
        this.meshMap.set(mesh, entry);
      }
    }

    if (!isMobile) {
      canvas.addEventListener('mousemove', (e) => {
        const locked = document.pointerLockElement === this.canvas;
        if (locked) {
          this.updateHoverCenter();
        } else {
          this.updateHover(e.clientX, e.clientY);
        }
      });
      canvas.addEventListener('mousedown', (e) => {
        const locked = document.pointerLockElement === this.canvas;
        if (locked) {
          this.clickCenter();
        } else {
          this.click(e.clientX, e.clientY);
        }
      });
    } else {
      canvas.addEventListener(
        'touchstart',
        (e) => {
          const t = e.changedTouches[0];
          if (t) this.click(t.clientX, t.clientY);
          e.preventDefault();
        },
        { passive: false },
      );
    }
  }

  private pick(clientX: number, clientY: number): Interactable | null {
    this.setNdc(clientX, clientY);
    return this.pickCurrentNdc();
  }

  private pickCenter(): Interactable | null {
    this.ndc.set(0, 0);
    return this.pickCurrentNdc();
  }

  private pickCurrentNdc(): Interactable | null {
    this.raycaster.setFromCamera(this.ndc, this.camera);

    const meshes = [...this.meshMap.keys()];
    const hit = this.raycaster.intersectObjects(meshes, false)[0];
    const staticHit = this.raycaster.intersectObjects(this.statics, false)[0];

    if (hit && (!staticHit || hit.distance < staticHit.distance)) {
      return this.meshMap.get(hit.object) ?? null;
    }
    return null;
  }

  private setNdc(clientX: number, clientY: number): void {
    const rect = this.canvas.getBoundingClientRect();
    this.ndc.set(
      ((clientX - rect.left) / rect.width) * 2 - 1,
      -((clientY - rect.top) / rect.height) * 2 + 1,
    );
  }

  private updateHover(clientX: number, clientY: number): void {
    this.applyHover(this.pick(clientX, clientY));
  }

  private updateHoverCenter(): void {
    this.applyHover(this.pickCenter());
  }

  private applyHover(entry: Interactable | null): void {
    if (entry === this.hovered) return;
    if (this.hovered?.onUnhover) this.hovered.onUnhover();
    this.hovered = entry;
    if (this.hovered?.onHover) this.hovered.onHover();
  }

  private click(clientX: number, clientY: number): void {
    // While the viewer covers the screen, the next click closes it (Godot's
    // ignore_clicks behavior). Pointer lock keeps events on the canvas, so
    // the overlay itself never sees them on desktop.
    if (this.viewer.isOpen) {
      this.viewer.hide();
      return;
    }
    this.pick(clientX, clientY)?.onClick();
  }

  private clickCenter(): void {
    if (this.viewer.isOpen) {
      this.viewer.hide();
      return;
    }
    this.pickCenter()?.onClick();
  }
}
