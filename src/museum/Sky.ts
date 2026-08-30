// Gradient sky dome (replaces Godot's flat grey clear color).
// Colors are authored in sRGB hex and mixed in linear space; the shader ends
// with three's colorspace conversion chunk so output matches other materials.
import * as THREE from 'three';
import { SKY_TOP, SKY_HORIZON, SKY_BOTTOM } from '../config.js';

export function createSky(): THREE.Mesh {
  const geometry = new THREE.SphereGeometry(1500, 24, 16);
  const material = new THREE.ShaderMaterial({
    side: THREE.BackSide,
    depthWrite: false,
    fog: false,
    uniforms: {
      top: { value: new THREE.Color(SKY_TOP) },
      horizon: { value: new THREE.Color(SKY_HORIZON) },
      bottom: { value: new THREE.Color(SKY_BOTTOM) },
    },
    vertexShader: /* glsl */ `
      varying vec3 vDir;
      void main() {
        vDir = normalize(position);
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: /* glsl */ `
      varying vec3 vDir;
      uniform vec3 top;
      uniform vec3 horizon;
      uniform vec3 bottom;
      void main() {
        float h = vDir.y;
        vec3 c = h >= 0.0
          ? mix(horizon, top, smoothstep(0.0, 0.55, h))
          : mix(horizon, bottom, smoothstep(0.0, 0.35, -h));
        gl_FragColor = vec4(c, 1.0);
        #include <colorspace_fragment>
      }
    `,
  });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.frustumCulled = false;
  mesh.renderOrder = -1;
  return mesh;
}
