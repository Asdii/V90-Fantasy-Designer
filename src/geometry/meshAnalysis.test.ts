import { describe, expect, it } from 'vitest';
import { calculateBoundingBox, isDegenerateTriangle } from './meshAnalysis';
import { createGemGeometryFromTriangleSoup } from './meshBuilder';
import { dot, triangleNormal } from './vectorMath';

describe('geometry analysis', () => {
  it('calculates bounding box dimensions and center', () => {
    const box = calculateBoundingBox([
      { x: -1, y: 2, z: 0.5 },
      { x: 4, y: -2, z: 3.5 },
    ]);

    expect(box.size).toEqual({ x: 5, y: 4, z: 3 });
    expect(box.center).toEqual({ x: 1.5, y: 0, z: 2 });
  });

  it('calculates triangle normals from winding', () => {
    const normal = triangleNormal(
      { x: 0, y: 0, z: 0 },
      { x: 1, y: 0, z: 0 },
      { x: 0, y: 1, z: 0 },
    );

    expect(normal.x).toBeCloseTo(0);
    expect(normal.y).toBeCloseTo(0);
    expect(normal.z).toBeCloseTo(1);
  });

  it('welds duplicated vertices without an O(n squared) scan', () => {
    const geometry = createGemGeometryFromTriangleSoup([
      [{ x: 0, y: 0, z: 0 }, { x: 1, y: 0, z: 0 }, { x: 0, y: 1, z: 0 }],
      [{ x: 0, y: 0, z: 0 }, { x: 0, y: 1, z: 0 }, { x: 0, y: 0, z: 1 }],
    ]);

    expect(geometry.vertices).toHaveLength(4);
    expect(geometry.triangles).toHaveLength(2);
  });

  it('detects colinear degenerate triangles', () => {
    expect(
      isDegenerateTriangle(
        { x: 0, y: 0, z: 0 },
        { x: 1, y: 1, z: 1 },
        { x: 2, y: 2, z: 2 },
      ),
    ).toBe(true);
  });

  it('orients a closed tetrahedron with outward normals', () => {
    const geometry = createGemGeometryFromTriangleSoup([
      [{ x: 1, y: 1, z: 1 }, { x: 1, y: -1, z: -1 }, { x: -1, y: 1, z: -1 }],
      [{ x: 1, y: 1, z: 1 }, { x: -1, y: -1, z: 1 }, { x: 1, y: -1, z: -1 }],
      [{ x: 1, y: 1, z: 1 }, { x: -1, y: 1, z: -1 }, { x: -1, y: -1, z: 1 }],
      [{ x: -1, y: -1, z: 1 }, { x: -1, y: 1, z: -1 }, { x: 1, y: -1, z: -1 }],
    ]);

    for (const facet of geometry.facets) {
      expect(dot(facet.normal, facet.centroid)).toBeGreaterThan(0);
    }
  });
});
