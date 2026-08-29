// Port of character_body_3d.gd _unhandled_input picking + Painting.gd reactions.
// Desktop: hover from mouse position (screen-center ray while pointer-locked,
// matching Godot's captured-mouse behavior); touch taps click directly.
import * as THREE from 'three';
import type { Painting } from '../museum/Painting.js';
import type { PaintingViewer } from '../ui/PaintingViewer.js';

export class Interaction {
  private raycaster = new THREE.Raycaster();
  private hovered: Painting | null = null;
  private ndc = new THREE.Vector2();

  constructor(
    private camera: THREE.Camera,
    private paintings: Painting[],
    private statics: THREE.Object3D[],
    private viewer: PaintingViewer,
    private canvas: HTMLCanvasElement,
    isMobile: boolean,
  ) {
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

  private setNdc(clientX: number, clientY: number): void {
    const rect = this.canvas.getBoundingClientRect();
    this.ndc.set(
      ((clientX - rect.left) / rect.width) * 2 - 1,
      -((clientY - rect.top) / rect.height) * 2 + 1,
    );
  }

  private pick(clientX: number, clientY: number): Painting | null {
    this.setNdc(clientX, clientY);
    return this.pickCurrentNdc();
  }

  private pickCenter(): Painting | null {
    this.ndc.set(0, 0);
    return this.pickCurrentNdc();
  }

  private pickCurrentNdc(): Painting | null {
    this.raycaster.setFromCamera(this.ndc, this.camera);

    const paintingMeshes: THREE.Object3D[] = [];
    for (const p of this.paintings) paintingMeshes.push(...p.pickMeshes);
    const paintingHit = this.raycaster.intersectObjects(paintingMeshes, false)[0];
    const staticHit = this.raycaster.intersectObjects(this.statics, false)[0];

    if (paintingHit && (!staticHit || paintingHit.distance < staticHit.distance)) {
      return (paintingHit.object.userData.painting as Painting) ?? null;
    }
    return null;
  }

  private updateHover(clientX: number, clientY: number): void {
    this.applyHover(this.pick(clientX, clientY));
  }

  private updateHoverCenter(): void {
    this.applyHover(this.pickCenter());
  }

  private applyHover(painting: Painting | null): void {
    if (painting === this.hovered) return;
    if (this.hovered) this.hovered.onHoverExit();
    this.hovered = painting;
    if (this.hovered) this.hovered.onHoverEnter();
  }

  private click(clientX: number, clientY: number): void {
    const painting = this.pick(clientX, clientY);
    if (painting) {
      this.viewer.show(painting.imageUrl, painting.fileName);
    }
  }

  private clickCenter(): void {
    const painting = this.pickCenter();
    if (painting) {
      this.viewer.show(painting.imageUrl, painting.fileName);
    }
  }
}
