import type { GemGeometry, Triangle, Vec3 } from './GemGeometry';
import { detectFacets } from './FacetDetector';
import {
  WELD_EPSILON_MM,
  calculateBoundingBox,
  deriveEdges,
  isDegenerateTriangle,
} from './meshAnalysis';
import { orientTrianglesOutward } from './meshOrientation';
import { triangleNormal } from './vectorMath';

export type TriangleSoup = readonly (readonly [Vec3, Vec3, Vec3])[];

export interface MeshBuildOptions {
  readonly weldEpsilonMm?: number;
}

export interface IndexedTriangle {
  readonly a: number;
  readonly b: number;
  readonly c: number;
}

export function createGemGeometryFromTriangleSoup(
  triangleSoup: TriangleSoup,
  options: MeshBuildOptions = {},
): GemGeometry {
  const weldEpsilon = options.weldEpsilonMm ?? WELD_EPSILON_MM;
  const vertices: Vec3[] = [];
  const triangles: Triangle[] = [];
  const vertexBuckets = new Map<string, number[]>();
  let degenerateTriangleCount = 0;

  for (const [a, b, c] of triangleSoup) {
    if (isDegenerateTriangle(a, b, c, weldEpsilon)) {
      degenerateTriangleCount += 1;
      continue;
    }

    const ia = weldVertex(a, vertices, vertexBuckets, weldEpsilon);
    const ib = weldVertex(b, vertices, vertexBuckets, weldEpsilon);
    const ic = weldVertex(c, vertices, vertexBuckets, weldEpsilon);

    if (ia === ib || ib === ic || ia === ic) {
      degenerateTriangleCount += 1;
      continue;
    }

    triangles.push({
      a: ia,
      b: ib,
      c: ic,
      normal: triangleNormal(vertices[ia], vertices[ib], vertices[ic]),
    });
  }

  const orientation = orientTrianglesOutward(vertices, triangles);
  const orientedTriangles = orientation.triangles;
  const boundingBox = calculateBoundingBox(vertices);
  const edges = deriveEdges({ triangles: orientedTriangles });
  const facetDetection = detectFacets({ vertices, triangles: orientedTriangles });
  const warnings =
    degenerateTriangleCount > 0
      ? [
          {
            code: 'degenerate-triangles' as const,
            count: degenerateTriangleCount,
            message: `${degenerateTriangleCount} degenerate triangle${
              degenerateTriangleCount === 1 ? '' : 's'
            } found`,
          },
        ]
      : [];

  return {
    units: 'millimeters',
    vertices,
    triangles: orientedTriangles,
    edges,
    facets: facetDetection.facets,
    boundingBox,
    warnings: [...warnings, ...orientation.warnings, ...facetDetection.topology.warnings],
  };
}

/** Builds domain geometry from a kernel-owned topology without spatial welding. */
export function createGemGeometryFromIndexedMesh(
  sourceVertices: readonly Vec3[],
  sourceTriangles: readonly IndexedTriangle[],
): GemGeometry {
  const vertices = sourceVertices.map((vertex) => ({ ...vertex }));
  const triangles = sourceTriangles.map((triangle) => ({
    ...triangle,
    normal: triangleNormal(vertices[triangle.a], vertices[triangle.b], vertices[triangle.c]),
  }));
  const orientation = orientTrianglesOutward(vertices, triangles);
  const orientedTriangles = orientation.triangles;
  const boundingBox = calculateBoundingBox(vertices);
  const edges = deriveEdges({ triangles: orientedTriangles });
  const facetDetection = detectFacets({ vertices, triangles: orientedTriangles });

  return {
    units: 'millimeters',
    vertices,
    triangles: orientedTriangles,
    edges,
    facets: facetDetection.facets,
    boundingBox,
    warnings: [...orientation.warnings, ...facetDetection.topology.warnings],
  };
}

function weldVertex(
  vertex: Vec3,
  vertices: Vec3[],
  vertexBuckets: Map<string, number[]>,
  epsilon: number,
) {
  const cell = quantize(vertex, epsilon);

  for (let dz = -1; dz <= 1; dz += 1) {
    for (let dy = -1; dy <= 1; dy += 1) {
      for (let dx = -1; dx <= 1; dx += 1) {
        const key = cellKey(cell.x + dx, cell.y + dy, cell.z + dz);
        const bucket = vertexBuckets.get(key);
        if (!bucket) {
          continue;
        }

        for (const index of bucket) {
          const candidate = vertices[index];
          if (
            Math.abs(candidate.x - vertex.x) <= epsilon &&
            Math.abs(candidate.y - vertex.y) <= epsilon &&
            Math.abs(candidate.z - vertex.z) <= epsilon
          ) {
            return index;
          }
        }
      }
    }
  }

  const index = vertices.length;
  vertices.push({ x: vertex.x, y: vertex.y, z: vertex.z });
  const ownKey = cellKey(cell.x, cell.y, cell.z);
  const ownBucket = vertexBuckets.get(ownKey) ?? [];
  ownBucket.push(index);
  vertexBuckets.set(ownKey, ownBucket);
  return index;
}

function quantize(vertex: Vec3, epsilon: number) {
  return {
    x: Math.floor(vertex.x / epsilon),
    y: Math.floor(vertex.y / epsilon),
    z: Math.floor(vertex.z / epsilon),
  };
}

function cellKey(x: number, y: number, z: number) {
  return `${x}:${y}:${z}`;
}
