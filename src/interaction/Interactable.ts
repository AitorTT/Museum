import type * as THREE from 'three';

/**
 * A clickable/hoverable world object (painting, elevator button, ...).
 * Meshes must be registered via pickMeshes; Interaction maps mesh -> entry.
 */
export interface Interactable {
  pickMeshes: THREE.Object3D[];
  onHover?(): void;
  onUnhover?(): void;
  onClick(): void;
}
