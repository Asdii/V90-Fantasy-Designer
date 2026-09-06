import type { GemGeometry, Triangle, Vec3 } from '../../geometry/GemGeometry';
import { add, cross, dot, scale, subtract } from '../../geometry/vectorMath';

export interface OpticalRay {
  readonly origin: Vec3;
  readonly direction: Vec3;
}

export interface OpticalHit {
  readonly triangleIndex: number;
  readonly distance: number;
  readonly point: Vec3;
  readonly normal: Vec3;
}

interface BvhNode {
  readonly bounds: Bounds;
  readonly left?: BvhNode;
  readonly right?: BvhNode;
  readonly triangleIndices?: readonly number[];
}

interface Bounds {
  readonly min: Vec3;
  readonly max: Vec3;
}

const LEAF_TRIANGLE_COUNT = 8;

export class OpticalBVH {
  private readonly root: BvhNode;

  constructor(private readonly geometry: Pick<GemGeometry, 'vertices' | 'triangles'>) {
    this.root = buildNode(geometry, geometry.triangles.map((_, index) => index));
  }

  intersect(ray: OpticalRay, minDistance = 1e-6): OpticalHit | undefined {
    let nearest: OpticalHit | undefined;
    const visit = (node: BvhNode) => {
      if (!intersectBounds(ray, node.bounds, minDistance, nearest?.distance ?? Infinity)) {
        return;
      }

      if (node.triangleIndices) {
        for (const triangleIndex of node.triangleIndices) {
          const hit = intersectTriangle(ray, this.geometry.triangles[triangleIndex], triangleIndex, this.geometry.vertices, minDistance);
          if (hit && hit.distance < (nearest?.distance ?? Infinity)) {
            nearest = hit;
          }
        }
        return;
      }

      if (node.left) {
        visit(node.left);
      }
      if (node.right) {
        visit(node.right);
      }
    };

    visit(this.root);
    return nearest;
  }
}

function buildNode(geometry: Pick<GemGeometry, 'vertices' | 'triangles'>, triangleIndices: readonly number[]): BvhNode {
  const bounds = boundsForTriangles(geometry, triangleIndices);
  if (triangleIndices.length <= LEAF_TRIANGLE_COUNT) {
    return { bounds, triangleIndices };
  }

  const axis = longestAxis(bounds);
  const sorted = [...triangleIndices].sort((a, b) => triangleCentroidAxis(geometry, a, axis) - triangleCentroidAxis(geometry, b, axis));
  const middle = Math.floor(sorted.length / 2);
  return {
    bounds,
    left: buildNode(geometry, sorted.slice(0, middle)),
    right: buildNode(geometry, sorted.slice(middle)),
  };
}

function boundsForTriangles(geometry: Pick<GemGeometry, 'vertices' | 'triangles'>, triangleIndices: readonly number[]): Bounds {
  const min = { x: Infinity, y: Infinity, z: Infinity };
  const max = { x: -Infinity, y: -Infinity, z: -Infinity };
  for (const triangleIndex of triangleIndices) {
    const triangle = geometry.triangles[triangleIndex];
    for (const vertexIndex of [triangle.a, triangle.b, triangle.c]) {
      const vertex = geometry.vertices[vertexIndex];
      min.x = Math.min(min.x, vertex.x);
      min.y = Math.min(min.y, vertex.y);
      min.z = Math.min(min.z, vertex.z);
      max.x = Math.max(max.x, vertex.x);
      max.y = Math.max(max.y, vertex.y);
      max.z = Math.max(max.z, vertex.z);
    }
  }
  return { min, max };
}

function longestAxis(bounds: Bounds): 'x' | 'y' | 'z' {
  const size = subtract(bounds.max, bounds.min);
  if (size.x >= size.y && size.x >= size.z) {
    return 'x';
  }
  return size.y >= size.z ? 'y' : 'z';
}

function triangleCentroidAxis(geometry: Pick<GemGeometry, 'vertices' | 'triangles'>, triangleIndex: number, axis: 'x' | 'y' | 'z') {
  const triangle = geometry.triangles[triangleIndex];
  return (geometry.vertices[triangle.a][axis] + geometry.vertices[triangle.b][axis] + geometry.vertices[triangle.c][axis]) / 3;
}

function intersectBounds(ray: OpticalRay, bounds: Bounds, minDistance: number, maxDistance: number) {
  let near = minDistance;
  let far = maxDistance;
  for (const axis of ['x', 'y', 'z'] as const) {
    if (Math.abs(ray.direction[axis]) <= 1e-12) {
      if (ray.origin[axis] < bounds.min[axis] || ray.origin[axis] > bounds.max[axis]) {
        return false;
      }
      continue;
    }
    const inverse = 1 / ray.direction[axis];
    let t1 = (bounds.min[axis] - ray.origin[axis]) * inverse;
    let t2 = (bounds.max[axis] - ray.origin[axis]) * inverse;
    if (inverse < 0) {
      [t1, t2] = [t2, t1];
    }
    near = Math.max(near, t1);
    far = Math.min(far, t2);
    if (far < near) {
      return false;
    }
  }
  return true;
}

function intersectTriangle(
  ray: OpticalRay,
  triangle: Triangle,
  triangleIndex: number,
  vertices: readonly Vec3[],
  minDistance: number,
): OpticalHit | undefined {
  const epsilon = 1e-10;
  const a = vertices[triangle.a];
  const b = vertices[triangle.b];
  const c = vertices[triangle.c];
  const edge1 = subtract(b, a);
  const edge2 = subtract(c, a);
  const p = cross(ray.direction, edge2);
  const determinant = dot(edge1, p);
  if (Math.abs(determinant) <= epsilon) {
    return undefined;
  }

  const invDeterminant = 1 / determinant;
  const t = subtract(ray.origin, a);
  const u = dot(t, p) * invDeterminant;
  if (u < -epsilon || u > 1 + epsilon) {
    return undefined;
  }

  const q = cross(t, edge1);
  const v = dot(ray.direction, q) * invDeterminant;
  if (v < -epsilon || u + v > 1 + epsilon) {
    return undefined;
  }

  const distance = dot(edge2, q) * invDeterminant;
  if (distance <= minDistance) {
    return undefined;
  }

  return {
    triangleIndex,
    distance,
    point: add(ray.origin, scale(ray.direction, distance)),
    normal: triangle.normal,
  };
}
