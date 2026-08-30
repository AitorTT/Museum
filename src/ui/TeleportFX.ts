// Screen-space teleport feedback: a purple radial flash overlay plus a brief
// blur/saturate punch on the canvas (composited CSS, no post-processing pass).
export class TeleportFX {
  readonly overlay: HTMLDivElement;
  private canvas: HTMLCanvasElement | null = null;

  constructor() {
    this.overlay = document.createElement('div');
    this.overlay.id = 'warp-overlay';
    document.body.appendChild(this.overlay);
  }

  /** Wire the canvas once the renderer exists. */
  attachCanvas(canvas: HTMLCanvasElement): void {
    this.canvas = canvas;
  }

  trigger(): void {
    // Restart the CSS animations even on rapid back-to-back teleports
    this.overlay.classList.remove('active');
    this.overlay.offsetWidth; // reflow to reset the animation
    this.overlay.classList.add('active');

    if (this.canvas) {
      this.canvas.classList.remove('warping');
      this.canvas.offsetWidth;
      this.canvas.classList.add('warping');
    }
  }
}
