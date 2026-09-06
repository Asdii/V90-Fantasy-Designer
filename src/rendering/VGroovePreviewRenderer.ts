import * as THREE from 'three';
import type { GroovePreviewGeometry } from '../grooves';
import type { VGrooveDisplayMode } from '../grooves';

export class VGroovePreviewRenderer {
  private group = new THREE.Group();

  constructor(private readonly scene: THREE.Scene) {
    this.group.name = 'V-groove preview';
    this.scene.add(this.group);
  }

  render(
    geometry: GroovePreviewGeometry | undefined,
    displayMode: VGrooveDisplayMode,
    visible: boolean,
    showGrooveVectors = false,
  ) {
    this.clearGroup();
    if (!visible || !geometry) {
      return;
    }

    if ((displayMode === 'surfaces' || displayMode === 'both') && geometry.surfaceGuides?.length) {
      this.group.add(createGrooveSurfaceGuideMesh(geometry));
      const outlines = createSurfaceGuideLines(geometry);
      if (outlines) {
        this.group.add(outlines);
      }
    }

    if (displayMode === 'centerLines' || displayMode === 'both') {
      const lines = createCenterLineSegments(geometry);
      if (lines) {
        this.group.add(lines);
      }
    }

    if (showGrooveVectors && geometry.debugVectors) {
      this.addDebugVectors(geometry);
    }
  }

  dispose() {
    this.clearGroup();
    this.scene.remove(this.group);
  }

  private clearGroup() {
    for (const child of [...this.group.children]) {
      this.group.remove(child);
      if (child instanceof THREE.Mesh || child instanceof THREE.LineSegments) {
        child.geometry.dispose();
        disposeMaterial(child.material);
      } else if (child instanceof THREE.ArrowHelper) {
        child.traverse((part) => {
          const resource = part as THREE.Object3D & {
            geometry?: { dispose?: () => void };
            material?: THREE.Material | THREE.Material[];
          };
          resource.geometry?.dispose?.();
          if (resource.material) disposeMaterial(resource.material);
        });
      }
    }
  }

  private addDebugVectors(geometry: GroovePreviewGeometry) {
    if (!geometry.debugVectors) {
      return;
    }

    const bounds = new THREE.Box3();
    for (const vertex of geometry.vertices) {
      bounds.expandByPoint(new THREE.Vector3(vertex.x, vertex.y, vertex.z));
    }
    const length = Math.max(bounds.getSize(new THREE.Vector3()).length() * 0.35, 0.25);
    const origin = toVector3(geometry.debugVectors.origin);
    this.group.add(new THREE.ArrowHelper(toVector3(geometry.debugVectors.outwardNormal), origin, length, 0x7cff9b));
    this.group.add(new THREE.ArrowHelper(toVector3(geometry.debugVectors.insideDirection), origin, length, 0xff5a5f));
    this.group.add(new THREE.ArrowHelper(toVector3(geometry.debugVectors.tangent), origin, length, 0xffffff));
    this.group.add(new THREE.ArrowHelper(toVector3(geometry.debugVectors.sideways), origin, length, 0x25d0ff));
  }
}

function createGrooveSurfaceGuideMesh(groove: GroovePreviewGeometry) {
  const positions: number[] = [];
  const colors: number[] = [];
  const normal = groove.outwardNormal ?? { x: 0, y: 0, z: 1 };
  const offset = Math.max((groove.depthMm ?? 0) * 0.025, 0.003);
  const edgeColor = new THREE.Color(0x55e4ff);
  const centerColor = new THREE.Color(0x07566f);

  for (const guide of groove.surfaceGuides ?? []) {
    addGuideTriangle(positions, colors, normal, offset, guide.startLeft, guide.endLeft, guide.endCenter, edgeColor, edgeColor, centerColor);
    addGuideTriangle(positions, colors, normal, offset, guide.startLeft, guide.endCenter, guide.startCenter, edgeColor, centerColor, centerColor);
    addGuideTriangle(positions, colors, normal, offset, guide.startCenter, guide.endCenter, guide.endRight, centerColor, centerColor, edgeColor);
    addGuideTriangle(positions, colors, normal, offset, guide.startCenter, guide.endRight, guide.startRight, centerColor, edgeColor, edgeColor);
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  geometry.computeBoundingSphere();

  const mesh = new THREE.Mesh(
    geometry,
    new THREE.MeshStandardMaterial({
      color: 0xffffff,
      vertexColors: true,
      emissive: 0x063746,
      emissiveIntensity: 0.45,
      metalness: 0,
      roughness: 0.5,
      transparent: true,
      opacity: 0.88,
      side: THREE.DoubleSide,
      depthWrite: false,
      depthTest: false,
    }),
  );
  mesh.name = 'V-groove surface guide';
  mesh.renderOrder = 8;
  return mesh;
}

function createSurfaceGuideLines(groove: GroovePreviewGeometry) {
  const points: THREE.Vector3[] = [];
  const normal = groove.outwardNormal ?? { x: 0, y: 0, z: 1 };
  const offset = Math.max((groove.depthMm ?? 0) * 0.03, 0.004);
  for (const guide of groove.surfaceGuides ?? []) {
    for (const [start, end] of [
      [guide.startLeft, guide.endLeft],
      [guide.startRight, guide.endRight],
    ] as const) {
      points.push(offsetPoint(start, normal, offset), offsetPoint(end, normal, offset));
    }
  }
  if (points.length === 0) {
    return undefined;
  }
  const lines = new THREE.LineSegments(
    new THREE.BufferGeometry().setFromPoints(points),
    new THREE.LineBasicMaterial({ color: 0x6be8ff, transparent: true, opacity: 1, depthTest: false }),
  );
  lines.name = 'V-groove opening outline';
  lines.renderOrder = 9;
  return lines;
}

function createCenterLineSegments(groove: GroovePreviewGeometry) {
  const points: THREE.Vector3[] = [];
  const normal = groove.outwardNormal ?? { x: 0, y: 0, z: 1 };
  const offset = Math.max((groove.depthMm ?? 0) * 0.035, 0.005);
  for (const path of groove.centerLines) {
    for (let index = 0; index + 1 < path.points.length; index += 1) {
      const start = path.points[index];
      const end = path.points[index + 1];
      points.push(offsetPoint(start, normal, offset), offsetPoint(end, normal, offset));
    }
  }

  if (points.length === 0) {
    return undefined;
  }

  const lines = new THREE.LineSegments(
    new THREE.BufferGeometry().setFromPoints(points),
    new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.95, depthTest: false }),
  );
  lines.name = 'V-groove center lines';
  lines.renderOrder = 9;
  return lines;
}

function addGuideTriangle(
  positions: number[],
  colors: number[],
  normal: { readonly x: number; readonly y: number; readonly z: number },
  offset: number,
  a: { readonly x: number; readonly y: number; readonly z: number },
  b: { readonly x: number; readonly y: number; readonly z: number },
  c: { readonly x: number; readonly y: number; readonly z: number },
  colorA: THREE.Color,
  colorB: THREE.Color,
  colorC: THREE.Color,
) {
  for (const point of [a, b, c]) {
    const shifted = offsetPoint(point, normal, offset);
    positions.push(shifted.x, shifted.y, shifted.z);
  }
  for (const color of [colorA, colorB, colorC]) {
    colors.push(color.r, color.g, color.b);
  }
}

function offsetPoint(
  point: { readonly x: number; readonly y: number; readonly z: number },
  normal: { readonly x: number; readonly y: number; readonly z: number },
  offset: number,
) {
  return new THREE.Vector3(point.x + normal.x * offset, point.y + normal.y * offset, point.z + normal.z * offset);
}

function disposeMaterial(material: THREE.Material | THREE.Material[]) {
  if (Array.isArray(material)) {
    material.forEach((item) => item.dispose?.());
    return;
  }
  material.dispose?.();
}

function toVector3(value: { readonly x: number; readonly y: number; readonly z: number }) {
  return new THREE.Vector3(value.x, value.y, value.z);
}
