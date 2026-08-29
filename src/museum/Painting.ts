// Port of SCENES/objects/Painting.gd + RoomBuilder._add_painting.
// Mount group's +Z faces into the room; frame is 4 merged bars, canvas an
// unshaded textured plane floating just in front of the frame.
import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import {
  PAINTING_SCALE,
  FRAME_PADDING,
  FRAME_DEPTH,
  FRAME_COLOR_LINEAR,
  HOVER_GLOW_LINEAR,
  HOVER_GLOW_STRENGTH,
} from '../config.js';

export class Painting {
  readonly group = new THREE.Group();
  readonly fileName: string;
  readonly imageUrl: string;
  readonly pickMeshes: THREE.Mesh[] = [];
  private readonly frameMat: THREE.MeshLambertMaterial;

  constructor(texture: THREE.Texture, fileName: string, imageUrl: string) {
    this.fileName = fileName;
    this.imageUrl = imageUrl;

    const img = texture.image as TexImageSource & { width: number; height: number };
    const aspect = img.height > 0 ? img.width / img.height : 1;

    const fp = FRAME_PADDING;
    const fd = FRAME_DEPTH;
    const s = PAINTING_SCALE;
    const fw = (aspect + fp * 2) * s;
    const fh = (1 + fp * 2) * s;
    const barT = fp * s;
    const barD = fd * s;

    this.frameMat = new THREE.MeshLambertMaterial();
    this.frameMat.color.setRGB(
      FRAME_COLOR_LINEAR.r,
      FRAME_COLOR_LINEAR.g,
      FRAME_COLOR_LINEAR.b,
      THREE.LinearSRGBColorSpace,
    );

    // Frame bars (RoomBuilder._add_painting segs)
    const bars: THREE.BoxGeometry[] = [
      new THREE.BoxGeometry(fw, barT, barD), // top
      new THREE.BoxGeometry(fw, barT, barD), // bottom
      new THREE.BoxGeometry(barT, fh, barD), // left
      new THREE.BoxGeometry(barT, fh, barD), // right
    ];
    const halfW = fw / 2 - barT / 2;
    const halfH = fh / 2 - barT / 2;
    bars[0].translate(0, halfH, 0);
    bars[1].translate(0, -halfH, 0);
    bars[2].translate(-halfW, 0, 0);
    bars[3].translate(halfW, 0, 0);
    const frameGeom = mergeGeometries(bars, false);
    bars.forEach((b) => b.dispose());
    const frameMesh = new THREE.Mesh(frameGeom, this.frameMat);
    this.group.add(frameMesh);
    this.pickMeshes.push(frameMesh);

    // Canvas: unshaded textured plane, slightly proud of the frame
    texture.colorSpace = THREE.SRGBColorSpace;
    const canvasMat = new THREE.MeshBasicMaterial({ map: texture });
    const canvasGeom = new THREE.PlaneGeometry(aspect * s, 1.0 * s);
    const canvasMesh = new THREE.Mesh(canvasGeom, canvasMat);
    canvasMesh.position.z = 0.0625 * s;
    this.group.add(canvasMesh);
    this.pickMeshes.push(canvasMesh);

    for (const m of this.pickMeshes) {
      m.userData.painting = this;
    }
  }

  onHoverEnter(): void {
    this.frameMat.emissive.setRGB(
      HOVER_GLOW_LINEAR.r,
      HOVER_GLOW_LINEAR.g,
      HOVER_GLOW_LINEAR.b,
      THREE.LinearSRGBColorSpace,
    );
    this.frameMat.emissiveIntensity = HOVER_GLOW_STRENGTH;
  }

  onHoverExit(): void {
    this.frameMat.emissive.setRGB(0, 0, 0);
    this.frameMat.emissiveIntensity = 1;
  }
}
