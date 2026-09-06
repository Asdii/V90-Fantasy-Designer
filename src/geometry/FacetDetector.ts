import type { Facet } from './Facet';
import type { Edge, GemGeometry, Triangle, Vec3 } from './GemGeometry';
import { createPlaneFromPointNormal, distancePointToPlane } from './Plane';
import { createMeshTopology, getSharedEdge, type MeshTopology } from './MeshTopology';
import { add, dot, normalize, scale, triangleArea, triangleCentroid } from './vectorMath';

export const FACET_NORMAL_TOLERANCE_DEGREES = 0.1;
export const FACET_PLANE_TOLERANCE_MM = 1e-5;

export interface FacetDetectionOptions {
  readonly normalToleranceDegrees?: number;
  readonly planeToleranceMm?: number;
}

export interface FacetDetectionResult {
  readonly facets: readonly Facet[];
  readonly topology: MeshTopology;
}

export function detectFacets(
  geometry: Pick<GemGeometry, 'vertices' | 'triangles'>,
  options: FacetDetectionOptions = {},
): FacetDetectionResult {
  const normalToleranceDegrees = options.normalToleranceDegrees ?? FACET_NORMAL_TOLERANCE_DEGREES;
  const planeToleranceMm = options.planeToleranceMm ?? FACET_PLANE_TOLERANCE_MM;
  const normalDotThreshold = Math.cos((normalToleranceDegrees * Math.PI) / 180);
  const topology = createMeshTopology(geometry.triangles);
  const visited = new Set<number>();
  const facets: Facet[] = [];

  for (let triangleIndex = 0; triangleIndex < geometry.triangles.length; triangleIndex += 1) {
    if (visited.has(triangleIndex)) {
      continue;
    }

    const seedTriangle = geometry.triangles[triangleIndex];
    const seedPoint = geometry.vertices[seedTriangle.a];
    const seedPlane = createPlaneFromPointNormal(seedPoint, seedTriangle.normal);
    const triangleIndices: number[] = [];
    const queue = [triangleIndex];
    visited.add(triangleIndex);

    while (queue.length > 0) {
      const currentIndex = queue.shift() as number;
      triangleIndices.push(currentIndex);

      for (const neighborIndex of topology.triangleNeighbors[currentIndex]) {
        if (visited.has(neighborIndex)) {
          continue;
        }

        const neighbor = geometry.triangles[neighborIndex];
        if (isCoplanarNeighbor(neighbor, geometry.vertices, seedTriangle.normal, seedPlane, normalDotThreshold, planeToleranceMm)) {
          visited.add(neighborIndex);
          queue.push(neighborIndex);
        }
      }
    }

    facets.push(createFacet(facets.length, triangleIndices, geometry.vertices, geometry.triangles));
  }

  return { facets, topology };
}

function isCoplanarNeighbor(
  triangle: Triangle,
  vertices: readonly Vec3[],
  referenceNormal: Vec3,
  referencePlane: ReturnType<typeof createPlaneFromPointNormal>,
  normalDotThreshold: number,
  planeToleranceMm: number,
) {
  if (Math.abs(dot(referenceNormal, triangle.normal)) < normalDotThreshold) {
    return false;
  }

  return [triangle.a, triangle.b, triangle.c].every(
    (vertexIndex) => Math.abs(distancePointToPlane(vertices[vertexIndex], referencePlane)) <= planeToleranceMm,
  );
}

function createFacet(
  id: number,
  triangleIndices: readonly number[],
  vertices: readonly Vec3[],
  triangles: readonly Triangle[],
): Facet {
  const seedNormal = triangles[triangleIndices[0]].normal;
  let weightedNormal = { x: 0, y: 0, z: 0 };
  let weightedCentroid = { x: 0, y: 0, z: 0 };
  let areaSum = 0;
  const boundaryEdges = findBoundaryEdges(triangleIndices, triangles);

  for (const triangleIndex of triangleIndices) {
    const triangle = triangles[triangleIndex];
    const a = vertices[triangle.a];
    const b = vertices[triangle.b];
    const c = vertices[triangle.c];
    const area = triangleArea(a, b, c);
    const normalSign = dot(seedNormal, triangle.normal) < 0 ? -1 : 1;
    weightedNormal = add(weightedNormal, scale(triangle.normal, area * normalSign));
    weightedCentroid = add(weightedCentroid, scale(triangleCentroid(a, b, c), area));
    areaSum += area;
  }

  const normal = normalize(weightedNormal);
  const centroid = areaSum > 0 ? scale(weightedCentroid, 1 / areaSum) : vertices[triangles[triangleIndices[0]].a];
  const plane = createPlaneFromPointNormal(centroid, normal);
  const boundaryLoops = orderBoundaryLoops(boundaryEdges, vertices, normal);

  return {
    id,
    triangleIndices,
    normal,
    plane,
    area: areaSum,
    centroid,
    boundaryEdges,
    boundaryVertexIndices: boundaryLoops[0] ?? [],
    boundaryLoops,
  };
}

function findBoundaryEdges(triangleIndices: readonly number[], triangles: readonly Triangle[]): Edge[] {
  const edgeCounts = new Map<string, Edge & { count: number }>();

  for (const triangleIndex of triangleIndices) {
    const triangle = triangles[triangleIndex];
    addFacetEdge(edgeCounts, triangle.a, triangle.b);
    addFacetEdge(edgeCounts, triangle.b, triangle.c);
    addFacetEdge(edgeCounts, triangle.c, triangle.a);
  }

  return Array.from(edgeCounts.values())
    .filter((edge) => edge.count === 1)
    .map(({ a, b }) => ({ a, b }));
}

function addFacetEdge(edges: Map<string, Edge & { count: number }>, first: number, second: number) {
  const a = Math.min(first, second);
  const b = Math.max(first, second);
  const key = `${a}:${b}`;
  const edge = edges.get(key);
  if (edge) {
    edge.count += 1;
    return;
  }

  edges.set(key, { a, b, count: 1 });
}

function orderBoundaryLoops(
  boundaryEdges: readonly Edge[],
  vertices: readonly Vec3[],
  normal: Vec3,
): number[][] {
  const adjacency = new Map<number, number[]>();
  for (const edge of boundaryEdges) {
    addBoundaryNeighbor(adjacency, edge.a, edge.b);
    addBoundaryNeighbor(adjacency, edge.b, edge.a);
  }

  const unusedEdges = new Set(boundaryEdges.map((edge) => `${edge.a}:${edge.b}`));
  const loops: number[][] = [];

  while (unusedEdges.size > 0) {
    const firstKey = unusedEdges.values().next().value as string;
    const [startText, nextText] = firstKey.split(':');
    const start = Number(startText);
    let previous = start;
    let current = Number(nextText);
    const loop = [start];
    removeBoundaryEdge(unusedEdges, start, current);

    while (current !== start) {
      loop.push(current);
      const neighbors = adjacency.get(current) ?? [];
      const next = neighbors.find((candidate) => candidate !== previous && unusedEdges.has(edgeKey(current, candidate)));
      if (next === undefined) {
        break;
      }

      previous = current;
      current = next;
      removeBoundaryEdge(unusedEdges, previous, current);
    }

    if (loop.length >= 3 && dot(loopAreaNormal(loop, vertices), normal) < 0) {
      loop.reverse();
    }
    loops.push(loop);
  }

  return loops;
}

function addBoundaryNeighbor(adjacency: Map<number, number[]>, from: number, to: number) {
  const neighbors = adjacency.get(from) ?? [];
  neighbors.push(to);
  adjacency.set(from, neighbors);
}

function removeBoundaryEdge(unusedEdges: Set<string>, a: number, b: number) {
  unusedEdges.delete(edgeKey(a, b));
}

function edgeKey(a: number, b: number) {
  return `${Math.min(a, b)}:${Math.max(a, b)}`;
}

function loopAreaNormal(loop: readonly number[], vertices: readonly Vec3[]): Vec3 {
  let areaNormal = { x: 0, y: 0, z: 0 };

  for (let index = 0; index < loop.length; index += 1) {
    const current = vertices[loop[index]];
    const next = vertices[loop[(index + 1) % loop.length]];
    areaNormal = add(areaNormal, {
      x: (current.y - next.y) * (current.z + next.z),
      y: (current.z - next.z) * (current.x + next.x),
      z: (current.x - next.x) * (current.y + next.y),
    });
  }

  return normalize(areaNormal);
}
