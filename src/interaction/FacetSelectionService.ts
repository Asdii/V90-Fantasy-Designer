import * as THREE from 'three';
import type { Facet } from '../geometry/Facet';
import type { GemGeometry, Triangle, Vec3 } from '../geometry/GemGeometry';
import { cross, dot, scale, subtract } from '../geometry/vectorMath';
import type { AppCamera } from '../rendering/CameraSystem';

export const CLICK_DRAG_THRESHOLD_PX = 4;

export interface FacetSelectionInfo {
  readonly facetId: number;
  readonly triangleCount: number;
  readonly area: number;
  readonly centroid: Facet['centroid'];
  readonly normal: Facet['normal'];
  readonly plane: Facet['plane'];
  readonly boundaryVertexCount: number;
}

export function buildTriangleToFacetMap(geometry: Pick<GemGeometry, 'triangles' | 'facets'>): Int32Array {
  const triangleToFacet = new Int32Array(geometry.triangles.length);
  triangleToFacet.fill(-1);

  for (const facet of geometry.facets) {
    for (const triangleIndex of facet.triangleIndices) {
      triangleToFacet[triangleIndex] = facet.id;
    }
  }

  return triangleToFacet;
}

export function pickFacetFromTriangle(
  triangleIndex: number | undefined,
  triangleToFacet: Int32Array,
): number | undefined {
  if (triangleIndex === undefined || triangleIndex < 0 || triangleIndex >= triangleToFacet.length) {
    return undefined;
  }

  const facetId = triangleToFacet[triangleIndex];
  return facetId >= 0 ? facetId : undefined;
}

export function createFacetSelectionInfo(facet: Facet): FacetSelectionInfo {
  return {
    facetId: facet.id,
    triangleCount: facet.triangleIndices.length,
    area: facet.area,
    centroid: facet.centroid,
    normal: facet.normal,
    plane: facet.plane,
    boundaryVertexCount: facet.boundaryVertexIndices.length,
  };
}

export class FacetSelectionService {
  private readonly raycaster = new THREE.Raycaster();

  constructor(
    private readonly triangleToFacet: Int32Array,
    private readonly geometry: Pick<GemGeometry, 'vertices' | 'triangles'>,
  ) {}

  pickFacet(
    pointerClientX: number,
    pointerClientY: number,
    canvas: HTMLCanvasElement,
    camera: AppCamera,
    selectableGemMesh?: THREE.Mesh,
  ): number | undefined {
    if (!selectableGemMesh) {
      return undefined;
    }

    const rect = canvas.getBoundingClientRect();
    const ndc = new THREE.Vector2(
      ((pointerClientX - rect.left) / rect.width) * 2 - 1,
      -(((pointerClientY - rect.top) / rect.height) * 2 - 1),
    );

    this.raycaster.setFromCamera(ndc, camera);
    return pickNearestVisibleFacet(this.raycaster.ray.origin, this.raycaster.ray.direction, this.geometry, this.triangleToFacet);
  }
}

export function pickNearestVisibleFacet(
  rayOrigin: Vec3,
  rayDirection: Vec3,
  geometry: Pick<GemGeometry, 'vertices' | 'triangles'>,
  triangleToFacet: Int32Array,
): number | undefined {
  let nearestTriangleIndex: number | undefined;
  let nearestDistance = Infinity;

  geometry.triangles.forEach((triangle, triangleIndex) => {
    if (dot(rayDirection, triangle.normal) >= -1e-9) {
      return;
    }

    const distance = intersectRayTriangle(rayOrigin, rayDirection, triangle, geometry.vertices);
    if (distance !== undefined && distance < nearestDistance) {
      nearestTriangleIndex = triangleIndex;
      nearestDistance = distance;
    }
  });

  return pickFacetFromTriangle(nearestTriangleIndex, triangleToFacet);
}

function intersectRayTriangle(
  rayOrigin: Vec3,
  rayDirection: Vec3,
  triangle: Triangle,
  vertices: readonly Vec3[],
): number | undefined {
  const epsilon = 1e-9;
  const a = vertices[triangle.a];
  const b = vertices[triangle.b];
  const c = vertices[triangle.c];
  const edge1 = subtract(b, a);
  const edge2 = subtract(c, a);
  const p = cross(rayDirection, edge2);
  const determinant = dot(edge1, p);

  if (Math.abs(determinant) <= epsilon) {
    return undefined;
  }

  const invDeterminant = 1 / determinant;
  const t = subtract(rayOrigin, a);
  const u = dot(t, p) * invDeterminant;
  if (u < -epsilon || u > 1 + epsilon) {
    return undefined;
  }

  const q = cross(t, edge1);
  const v = dot(rayDirection, q) * invDeterminant;
  if (v < -epsilon || u + v > 1 + epsilon) {
    return undefined;
  }

  const distance = dot(edge2, q) * invDeterminant;
  return distance > epsilon ? distance : undefined;
}
