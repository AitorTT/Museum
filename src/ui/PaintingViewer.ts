// Minimal port of PaintingViewer.show_image: fullscreen overlay with the texture.
export class PaintingViewer {
  readonly root: HTMLDivElement;
  private img: HTMLImageElement;
  private caption: HTMLDivElement;
  private currentUrl = '';

  constructor() {
    this.root = document.createElement('div');
    this.root.id = 'painting-viewer';
    this.root.style.display = 'none';

    this.img = document.createElement('img');
    this.img.alt = '';
    this.root.appendChild(this.img);

    this.caption = document.createElement('div');
    this.caption.className = 'viewer-caption';
    this.root.appendChild(this.caption);

    const hint = document.createElement('div');
    hint.className = 'viewer-hint';
    hint.textContent = 'tap / click to close';
    this.root.appendChild(hint);

    this.root.addEventListener('pointerdown', () => this.hide());
    document.body.appendChild(this.root);
  }

  get isOpen(): boolean {
    return this.root.style.display !== 'none';
  }

  show(url: string, name: string): void {
    if (this.currentUrl === url && this.isOpen) return;
    this.currentUrl = url;
    this.img.src = url;
    this.caption.textContent = name.replace(/\.[^.]+$/, '');
    this.root.style.display = 'flex';
  }

  hide(): void {
    this.root.style.display = 'none';
    this.currentUrl = '';
  }
}
