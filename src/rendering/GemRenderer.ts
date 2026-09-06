import * as THREE from 'three';
import { localToWorld } from '../geometry/CoordinateTransforms';
import { createFacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import type { GemGeometry } from '../geometry/GemGeometry';
import type { GemMaterial } from '../materials/GemMaterial';
import { gemMaterialPresets } from '../materials/GemMaterial';
import {
  createFacetBoundaryGeometry,
  createFacetSurfaceGeometry,
  createRenderableGeometry,
  createSingleFacetBoundaryGeometry,
} from './createRenderableGeometry';

export interface GemRenderOptions {
  readonly showWireframe: boolean;
  readonly showFacetBoundaries: boolean;
  readonly showFacetNormals?: boolean;
  readonly facetDebugColors: boolean;
  readonly material?: GemMaterial;
}

export interface GemRendererAdapters {
  readonly createGeometry?: (geometry: GemGeometry, facetDebugColors: boolean) => THREE.BufferGeometry;
  readonly createMaterial?: (material: GemMaterial, facetDebugColors: boolean) => THREE.Material;
  readonly createMesh?: (geometry: THREE.BufferGeometry, material: THREE.Material) => THREE.Mesh;
  readonly onMeshCreated?: (mesh: THREE.Mesh, material: GemMaterial) => void;
}

export class GemRenderer {
  private mesh?: THREE.Mesh;
  private wireframe?: THREE.LineSegments;
  private facetBoundaries?: THREE.LineSegments;
  private facetNormals?: THREE.LineSegments;
  private hoverOverlay?: THREE.Mesh;
  private selectedOverlay?: THREE.Mesh;
  private selectedBoundary?: THREE.LineSegments;
  private centroidMarker?: THREE.Mesh;
  private frameArrows: THREE.ArrowHelper[] = [];
  private localWorkplane?: THREE.LineSegments;

  constructor(
    private readonly scene: THREE.Scene,
    private readonly adapters: GemRendererAdapters = {},
  ) {}

  setGeometry(
    geometry?: GemGeometry,
    options: GemRenderOptions = {
      showWireframe: false,
      showFacetBoundaries: false,
      facetDebugColors: false,
    },
  ) {
    if (!geometry) {
      this.clear();
      return;
    }

    const bufferGeometry = this.adapters.createGeometry?.(geometry, options.facetDebugColors)
      ?? createRenderableGeometry(geometry, { facetColors: options.facetDebugColors });
    const material = options.material ?? gemMaterialPresets.quartz;
    const renderMaterial = this.adapters.createMaterial?.(material, options.facetDebugColors)
      ?? createGemMeshMaterial(material, options.facetDebugColors);
    const nextMesh = this.adapters.createMesh?.(bufferGeometry, renderMaterial)
      ?? new THREE.Mesh(bufferGeometry, renderMaterial);
    nextMesh.name = 'Gem geometry';

    let nextWireframe: THREE.LineSegments | undefined;
    let nextFacetBoundaries: THREE.LineSegments | undefined;
    let nextFacetNormals: THREE.LineSegments | undefined;

    if (options.showWireframe) {
      nextWireframe = new THREE.LineSegments(
        new THREE.WireframeGeometry(bufferGeometry),
        new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.55 }),
      );
      nextWireframe.name = 'Gem triangle wireframe';
    }

    if (options.showFacetBoundaries) {
      nextFacetBoundaries = new THREE.LineSegments(
        createFacetBoundaryGeometry(geometry),
        new THREE.LineBasicMaterial({ color: 0xffd36e, transparent: true, opacity: 0.95 }),
      );
      nextFacetBoundaries.name = 'Facet boundary edges';
    }

    if (options.showFacetNormals) {
      nextFacetNormals = createFacetNormalGeometry(geometry);
    }

    // Commit only after every new render resource has been built successfully.
    console.debug('[WebGiMeshSwap] render resources prepared');
    this.clear();
    console.debug('[WebGiMeshSwap] previous gem detached');
    this.mesh = nextMesh;
    this.wireframe = nextWireframe;
    this.facetBoundaries = nextFacetBoundaries;
    this.facetNormals = nextFacetNormals;
    this.scene.add(nextMesh);
    if (nextWireframe) this.scene.add(nextWireframe);
    if (nextFacetBoundaries) this.scene.add(nextFacetBoundaries);
    if (nextFacetNormals) this.scene.add(nextFacetNormals);
    console.debug('[WebGiMeshSwap] new gem attached');
    this.adapters.onMeshCreated?.(nextMesh, material);
  }

  clear() {
    this.clearSelectionVisuals();

    if (this.mesh) {
      this.scene.remove(this.mesh);
      this.mesh.geometry.dispose();
      disposeMaterial(this.mesh.material);
      this.mesh = undefined;
    }

    if (this.wireframe) {
      this.scene.remove(this.wireframe);
      this.wireframe.geometry.dispose();
      disposeMaterial(this.wireframe.material);
      this.wireframe = undefined;
    }

    if (this.facetBoundaries) {
      this.scene.remove(this.facetBoundaries);
      this.facetBoundaries.geometry.dispose();
      disposeMaterial(this.facetBoundaries.material);
      this.facetBoundaries = undefined;
    }

    if (this.facetNormals) {
      this.scene.remove(this.facetNormals);
      this.facetNormals.geometry.dispose();
      disposeMaterial(this.facetNormals.material);
      this.facetNormals = undefined;
    }
  }

  getSelectableMesh() {
    return this.mesh;
  }

  setInteractionVisuals(
    geometry: GemGeometry,
    hoveredFacetId?: number,
    selectedFacetId?: number,
    showLocalWorkplane = false,
  ) {
    this.clearSelectionVisuals();

    const hoveredFacet =
      hoveredFacetId !== undefined && hoveredFacetId !== selectedFacetId
        ? geometry.facets.find((facet) => facet.id === hoveredFacetId)
        : undefined;
    const selectedFacet =
      selectedFacetId !== undefined ? geometry.facets.find((facet) => facet.id === selectedFacetId) : undefined;

    if (hoveredFacet) {
      this.hoverOverlay = new THREE.Mesh(
        createFacetSurfaceGeometry(geometry, hoveredFacet),
        new THREE.MeshBasicMaterial({
          color: 0xffffff,
          transparent: true,
          opacity: 0.16,
          depthWrite: false,
          side: THREE.DoubleSide,
        }),
      );
      this.hoverOverlay.name = 'Hovered facet overlay';
      this.scene.add(this.hoverOverlay);
    }

    if (selectedFacet) {
      const localGeometry = createFacetLocalGeometry(geometry, selectedFacet);
      this.selectedOverlay = new THREE.Mesh(
        createFacetSurfaceGeometry(geometry, selectedFacet),
        new THREE.MeshBasicMaterial({
          color: 0xffd36e,
          transparent: true,
          opacity: 0.24,
          depthWrite: false,
          side: THREE.DoubleSide,
        }),
      );
      this.selectedOverlay.name = 'Selected facet overlay';
      this.scene.add(this.selectedOverlay);

      this.selectedBoundary = new THREE.LineSegments(
        createSingleFacetBoundaryGeometry(geometry, selectedFacet),
        new THREE.LineBasicMaterial({ color: 0xffffff, linewidth: 3 }),
      );
      this.selectedBoundary.name = 'Selected facet boundary';
      this.scene.add(this.selectedBoundary);

      const diagonal = new THREE.Vector3(
        geometry.boundingBox.size.x,
        geometry.boundingBox.size.y,
        geometry.boundingBox.size.z,
      ).length();
      const markerRadius = Math.max(diagonal * 0.012, 0.035);
      const normal = toVector3(localGeometry.frame.normal);
      const origin = toVector3(localGeometry.frame.origin).add(normal.clone().multiplyScalar(markerRadius * 1.2));
      const axisLength = Math.max(Math.max(localGeometry.bounds.width, localGeometry.bounds.height) * 0.35, diagonal * 0.08, 0.25);

      this.centroidMarker = new THREE.Mesh(
        new THREE.SphereGeometry(markerRadius, 18, 10),
        new THREE.MeshBasicMaterial({ color: 0xffffff }),
      );
      this.centroidMarker.name = 'Selected facet centroid';
      this.centroidMarker.position.copy(origin);
      this.scene.add(this.centroidMarker);

      this.frameArrows = [
        createAxisArrow(toVector3(localGeometry.frame.uAxis), origin, axisLength, 0xff5a5f, 'Selected facet U axis'),
        createAxisArrow(toVector3(localGeometry.frame.vAxis), origin, axisLength, 0x2fd17c, 'Selected facet V axis'),
        createAxisArrow(toVector3(localGeometry.frame.normal), origin, axisLength, 0xffd36e, 'Selected facet N axis'),
      ];
      this.frameArrows.forEach((arrow) => this.scene.add(arrow));

      if (showLocalWorkplane) {
        this.localWorkplane = createLocalWorkplaneHelper(localGeometry, markerRadius * 1.4);
        this.scene.add(this.localWorkplane);
      }
    }
  }

  private clearSelectionVisuals() {
    if (this.hoverOverlay) {
      this.scene.remove(this.hoverOverlay);
      this.hoverOverlay.geometry.dispose();
      disposeMaterial(this.hoverOverlay.material);
      this.hoverOverlay = undefined;
    }

    if (this.selectedOverlay) {
      this.scene.remove(this.selectedOverlay);
      this.selectedOverlay.geometry.dispose();
      disposeMaterial(this.selectedOverlay.material);
      this.selectedOverlay = undefined;
    }

    if (this.selectedBoundary) {
      this.scene.remove(this.selectedBoundary);
      this.selectedBoundary.geometry.dispose();
      disposeMaterial(this.selectedBoundary.material);
      this.selectedBoundary = undefined;
    }

    if (this.centroidMarker) {
      this.scene.remove(this.centroidMarker);
      this.centroidMarker.geometry.dispose();
      disposeMaterial(this.centroidMarker.material);
      this.centroidMarker = undefined;
    }

    for (const arrow of this.frameArrows) {
      this.scene.remove(arrow);
      disposeObjectResources(arrow);
    }
    this.frameArrows = [];

    if (this.localWorkplane) {
      this.scene.remove(this.localWorkplane);
      this.localWorkplane.geometry.dispose();
      disposeMaterial(this.localWorkplane.material);
      this.localWorkplane = undefined;
    }
  }
}

function createGemMeshMaterial(material: GemMaterial = gemMaterialPresets.quartz, facetDebugColors = false) {
  return new THREE.MeshPhysicalMaterial({
    color: new THREE.Color(material.color),
    roughness: material.roughness,
    metalness: 0,
    transmission: material.transmission,
    thickness: 2.5,
    ior: material.refractiveIndex,
    reflectivity: 0.65,
    transparent: true,
    opacity: 1,
    flatShading: true,
    side: THREE.FrontSide,
    vertexColors: facetDebugColors,
  });
}

function createFacetNormalGeometry(geometry: GemGeometry) {
  const positions: number[] = [];
  const diagonal = new THREE.Vector3(
    geometry.boundingBox.size.x,
    geometry.boundingBox.size.y,
    geometry.boundingBox.size.z,
  ).length();
  const normalLength = Math.max(diagonal * 0.08, 0.25);

  for (const facet of geometry.facets) {
    positions.push(
      facet.centroid.x,
      facet.centroid.y,
      facet.centroid.z,
      facet.centroid.x + facet.normal.x * normalLength,
      facet.centroid.y + facet.normal.y * normalLength,
      facet.centroid.z + facet.normal.z * normalLength,
    );
  }

  const normals = new THREE.LineSegments(
    new THREE.BufferGeometry().setAttribute('position', new THREE.BufferAttribute(new Float32Array(positions), 3)),
    new THREE.LineBasicMaterial({ color: 0x7cff9b, transparent: true, opacity: 0.9 }),
  );
  normals.name = 'Facet outward normals';
  return normals;
}

function createAxisArrow(direction: THREE.Vector3, origin: THREE.Vector3, length: number, color: number, name: string) {
  const arrow = new THREE.ArrowHelper(direction.normalize(), origin, length, color, length * 0.22, length * 0.08);
  arrow.name = name;
  return arrow;
}

function createLocalWorkplaneHelper(
  localGeometry: ReturnType<typeof createFacetLocalGeometry>,
  offsetNormal: number,
) {
  const positions: number[] = [];
  const { minU, maxU, minV, maxV, width, height } = localGeometry.bounds;
  const spacing = chooseGridSpacing(Math.max(width, height));
  const startU = Math.floor(minU / spacing) * spacing;
  const endU = Math.ceil(maxU / spacing) * spacing;
  const startV = Math.floor(minV / spacing) * spacing;
  const endV = Math.ceil(maxV / spacing) * spacing;

  for (let u = startU; u <= endU + spacing * 0.5; u += spacing) {
    pushLine(positions, localGeometry, u, startV, u, endV, offsetNormal);
  }

  for (let v = startV; v <= endV + spacing * 0.5; v += spacing) {
    pushLine(positions, localGeometry, startU, v, endU, v, offsetNormal);
  }

  const grid = new THREE.LineSegments(
    new THREE.BufferGeometry().setAttribute('position', new THREE.BufferAttribute(new Float32Array(positions), 3)),
    new THREE.LineBasicMaterial({ color: 0x8fb7ff, transparent: true, opacity: 0.45 }),
  );
  grid.name = 'Selected facet local workplane';
  return grid;
}

function chooseGridSpacing(maxSize: number) {
  if (maxSize <= 2) {
    return 0.5;
  }
  return 1;
}

function pushLine(
  positions: number[],
  localGeometry: ReturnType<typeof createFacetLocalGeometry>,
  u1: number,
  v1: number,
  u2: number,
  v2: number,
  offsetNormal: number,
) {
  const a = localToWorld(localGeometry.frame, u1, v1, offsetNormal);
  const b = localToWorld(localGeometry.frame, u2, v2, offsetNormal);
  positions.push(a.x, a.y, a.z, b.x, b.y, b.z);
}

function toVector3(value: { readonly x: number; readonly y: number; readonly z: number }) {
  return new THREE.Vector3(value.x, value.y, value.z);
}

function disposeMaterial(material: THREE.Material | THREE.Material[]) {
  if (Array.isArray(material)) {
    material.forEach((item) => disposeIfSupported(item));
    return;
  }

  disposeIfSupported(material);
}

function disposeObjectResources(object: THREE.Object3D) {
  object.traverse((child) => {
    const renderObject = child as THREE.Object3D & {
      geometry?: { dispose?: () => void };
      material?: THREE.Material | THREE.Material[];
    };
    renderObject.geometry?.dispose?.();
    if (renderObject.material) {
      disposeMaterial(renderObject.material);
    }
  });
}

function disposeIfSupported(value: { dispose?: () => void } | undefined) {
  value?.dispose?.();
}
