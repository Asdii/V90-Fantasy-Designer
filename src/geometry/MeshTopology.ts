import type { Edge, GeometryWarning, Triangle } from './GemGeometry';

export interface EdgeTriangleUse {
  readonly triangleIndex: number;
  readonly from: number;
  readonly to: number;
}

export interface MeshTopology {
  readonly edgeTriangleMap: Map<string, readonly EdgeTriangleUse[]>;
  readonly triangleNeighbors: readonly (readonly number[])[];
  readonly warnings: readonly GeometryWarning[];
}

export function createEdgeKey(a: number, b: number): string {
  return `${Math.min(a, b)}:${Math.max(a, b)}`;
}

export function createMeshTopology(triangles: readonly Triangle[]): MeshTopology {
  const edgeTriangleMap = new Map<string, EdgeTriangleUse[]>();

  triangles.forEach((triangle, triangleIndex) => {
    addEdgeUse(edgeTriangleMap, triangleIndex, triangle.a, triangle.b);
    addEdgeUse(edgeTriangleMap, triangleIndex, triangle.b, triangle.c);
    addEdgeUse(edgeTriangleMap, triangleIndex, triangle.c, triangle.a);
  });

  const neighborSets = triangles.map(() => new Set<number>());
  let openEdges = 0;
  let nonManifoldEdges = 0;
  let inconsistentWindingEdges = 0;

  for (const uses of edgeTriangleMap.values()) {
    if (uses.length === 1) {
      openEdges += 1;
    } else if (uses.length > 2) {
      nonManifoldEdges += 1;
    }

    for (let i = 0; i < uses.length; i += 1) {
      for (let j = i + 1; j < uses.length; j += 1) {
        neighborSets[uses[i].triangleIndex].add(uses[j].triangleIndex);
        neighborSets[uses[j].triangleIndex].add(uses[i].triangleIndex);
      }
    }

    if (uses.length === 2 && uses[0].from === uses[1].from && uses[0].to === uses[1].to) {
      inconsistentWindingEdges += 1;
    }
  }

  const warnings: GeometryWarning[] = [];
  if (openEdges > 0) {
    warnings.push({ code: 'open-edges', count: openEdges, message: `Open edges: ${openEdges}` });
  }
  if (nonManifoldEdges > 0) {
    warnings.push({
      code: 'non-manifold-edges',
      count: nonManifoldEdges,
      message: `Non-manifold edges: ${nonManifoldEdges}`,
    });
  }
  if (inconsistentWindingEdges > 0) {
    warnings.push({
      code: 'inconsistent-winding',
      count: inconsistentWindingEdges,
      message: `Potential inconsistent winding edges: ${inconsistentWindingEdges}`,
    });
  }

  return {
    edgeTriangleMap,
    triangleNeighbors: neighborSets.map((neighbors) => Array.from(neighbors)),
    warnings,
  };
}

export function getSharedEdge(
  first: Triangle,
  second: Triangle,
): Edge | undefined {
  const firstVertices = [first.a, first.b, first.c];
  const secondVertices = new Set([second.a, second.b, second.c]);
  const shared = firstVertices.filter((vertexIndex) => secondVertices.has(vertexIndex));

  if (shared.length !== 2) {
    return undefined;
  }

  return {
    a: Math.min(shared[0], shared[1]),
    b: Math.max(shared[0], shared[1]),
  };
}

function addEdgeUse(
  edgeTriangleMap: Map<string, EdgeTriangleUse[]>,
  triangleIndex: number,
  from: number,
  to: number,
) {
  const key = createEdgeKey(from, to);
  const uses = edgeTriangleMap.get(key) ?? [];
  uses.push({ triangleIndex, from, to });
  edgeTriangleMap.set(key, uses);
}
