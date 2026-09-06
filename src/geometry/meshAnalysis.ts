import type { BoundingBox, Edge, GemGeometry, Vec3 } from './GemGeometry';
import { cross, distanceSquared, length, subtract } from './vectorMath';

export const WELD_EPSILON_MM = 1e-6;
export const DEGENERATE_AREA_EPSILON_MM2 = 1e-12;

export function calculateBoundingBox(vertices: readonly Vec3[]): BoundingBox {
  if (vertices.length === 0) {
    const zero = { x: 0, y: 0, z: 0 };
    return { min: zero, max: zero, size: zero, center: zero };
  }

  let minX = vertices[0].x;
  let minY = vertices[0].y;
  let minZ = vertices[0].z;
  let maxX = vertices[0].x;
  let maxY = vertices[0].y;
  let maxZ = vertices[0].z;

  for (const vertex of vertices) {
    minX = Math.min(minX, vertex.x);
    minY = Math.min(minY, vertex.y);
    minZ = Math.min(minZ, vertex.z);
    maxX = Math.max(maxX, vertex.x);
    maxY = Math.max(maxY, vertex.y);
    maxZ = Math.max(maxZ, vertex.z);
  }

  return {
    min: { x: minX, y: minY, z: minZ },
    max: { x: maxX, y: maxY, z: maxZ },
    size: { x: maxX - minX, y: maxY - minY, z: maxZ - minZ },
    center: { x: (minX + maxX) / 2, y: (minY + maxY) / 2, z: (minZ + maxZ) / 2 },
  };
}

export function isDegenerateTriangle(
  a: Vec3,
  b: Vec3,
  c: Vec3,
  weldEpsilon = WELD_EPSILON_MM,
  areaEpsilon = DEGENERATE_AREA_EPSILON_MM2,
) {
  const epsilonSquared = weldEpsilon * weldEpsilon;
  if (
    distanceSquared(a, b) <= epsilonSquared ||
    distanceSquared(b, c) <= epsilonSquared ||
    distanceSquared(a, c) <= epsilonSquared
  ) {
    return true;
  }

  const areaTimesTwo = length(cross(subtract(b, a), subtract(c, a)));
  return areaTimesTwo * areaTimesTwo <= 4 * areaEpsilon * areaEpsilon;
}

export function deriveEdges(geometry: Pick<GemGeometry, 'triangles'>): Edge[] {
  const edges = new Map<string, Edge>();

  for (const triangle of geometry.triangles) {
    addEdge(edges, triangle.a, triangle.b);
    addEdge(edges, triangle.b, triangle.c);
    addEdge(edges, triangle.c, triangle.a);
  }

  return Array.from(edges.values());
}

function addEdge(edges: Map<string, Edge>, first: number, second: number) {
  const a = Math.min(first, second);
  const b = Math.max(first, second);
  const key = `${a}:${b}`;

  if (!edges.has(key)) {
    edges.set(key, { a, b });
  }
}
