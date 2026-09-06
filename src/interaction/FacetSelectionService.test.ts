import { describe, expect, it } from 'vitest';
import type { Facet } from '../geometry/Facet';
import type { Triangle } from '../geometry/GemGeometry';
import { buildTriangleToFacetMap, pickFacetFromTriangle, pickNearestVisibleFacet } from './FacetSelectionService';

describe('FacetSelectionService', () => {
  it('builds O(1) triangle to facet mapping', () => {
    const triangles = [
      triangle(0, 1, 2),
      triangle(0, 2, 3),
      triangle(4, 5, 6),
      triangle(4, 6, 7),
      triangle(8, 9, 10),
    ];
    const facets = [
      facet(0, [0, 1, 2]),
      facet(1, [3, 4]),
    ];

    const map = buildTriangleToFacetMap({ triangles, facets });

    expect(Array.from(map)).toEqual([0, 0, 0, 1, 1]);
  });

  it('resolves a conceptual raycast triangle hit to the owning facet', () => {
    const triangleToFacet = new Int32Array([0, 0, 1, 2, 2, 2]);

    expect(pickFacetFromTriangle(5, triangleToFacet)).toBe(2);
  });

  it('selects the nearest front-facing surface, not a back surface behind it', () => {
    const vertices = [
      { x: -1, y: -1, z: 1 },
      { x: 1, y: -1, z: 1 },
      { x: 0, y: 1, z: 1 },
      { x: -1, y: -1, z: 0 },
      { x: 1, y: -1, z: 0 },
      { x: 0, y: 1, z: 0 },
    ];
    const triangles = [triangle(0, 2, 1), triangle(3, 5, 4)];
    const facets = [facet(0, [0]), facet(1, [1])];

    const selected = pickNearestVisibleFacet(
      { x: 0, y: 0, z: 10 },
      { x: 0, y: 0, z: -1 },
      { vertices, triangles },
      buildTriangleToFacetMap({ triangles, facets }),
    );

    expect(selected).toBe(0);
  });
});

function triangle(a: number, b: number, c: number): Triangle {
  return { a, b, c, normal: { x: 0, y: 0, z: 1 } };
}

function facet(id: number, triangleIndices: number[]): Facet {
  return {
    id,
    triangleIndices,
    normal: { x: 0, y: 0, z: 1 },
    plane: { normal: { x: 0, y: 0, z: 1 }, constant: 0 },
    area: 1,
    centroid: { x: 0, y: 0, z: 0 },
    boundaryEdges: [],
    boundaryVertexIndices: [],
    boundaryLoops: [],
  };
}
