import { describe, expect, it } from 'vitest';
import type { Vec3 } from './GemGeometry';
import { createGemGeometryFromTriangleSoup, type TriangleSoup } from './meshBuilder';

describe('facet detection', () => {
  it('detects one facet for a single triangle', () => {
    const geometry = createGemGeometryFromTriangleSoup([
      [v(0, 0, 0), v(1, 0, 0), v(0, 1, 0)],
    ]);

    expect(geometry.facets).toHaveLength(1);
    expect(geometry.facets[0].triangleIndices).toHaveLength(1);
  });

  it('detects one square facet from two coplanar triangles without exposing the diagonal', () => {
    const geometry = createGemGeometryFromTriangleSoup([
      [v(0, 0, 0), v(1, 0, 0), v(1, 1, 0)],
      [v(0, 0, 0), v(1, 1, 0), v(0, 1, 0)],
    ]);

    expect(geometry.triangles).toHaveLength(2);
    expect(geometry.facets).toHaveLength(1);
    expect(geometry.facets[0].boundaryEdges).toHaveLength(4);
    expect(geometry.facets[0].boundaryVertexIndices).toHaveLength(4);
  });

  it('detects six facets for a triangulated cube', () => {
    const geometry = createGemGeometryFromTriangleSoup(cubeSoup());

    expect(geometry.triangles).toHaveLength(12);
    expect(geometry.facets).toHaveLength(6);
    expect(geometry.facets.every((facet) => facet.boundaryEdges.length === 4)).toBe(true);
  });

  it('keeps two connected angled surfaces as separate facets', () => {
    const geometry = createGemGeometryFromTriangleSoup([
      [v(0, 0, 0), v(1, 0, 0), v(0, 1, 0)],
      [v(0, 0, 0), v(0, 1, 0), v(0, 0, 1)],
    ]);

    expect(geometry.facets).toHaveLength(2);
  });

  it('keeps coplanar disconnected triangles as separate facets', () => {
    const geometry = createGemGeometryFromTriangleSoup([
      [v(0, 0, 0), v(1, 0, 0), v(0, 1, 0)],
      [v(3, 0, 0), v(4, 0, 0), v(3, 1, 0)],
    ]);

    expect(geometry.facets).toHaveLength(2);
  });

  it('keeps parallel planes at different positions as separate facets', () => {
    const geometry = createGemGeometryFromTriangleSoup([
      [v(0, 0, 0), v(1, 0, 0), v(0, 1, 0)],
      [v(0, 0, 1), v(1, 0, 1), v(0, 1, 1)],
    ]);

    expect(geometry.facets).toHaveLength(2);
  });

  it('detects one facet and the exterior boundary for a triangulated hexagon', () => {
    const center = v(0, 0, 0);
    const ring = Array.from({ length: 6 }, (_, index) => {
      const angle = (index / 6) * Math.PI * 2;
      return v(Math.cos(angle), Math.sin(angle), 0);
    });
    const soup = ring.map((point, index) => [center, point, ring[(index + 1) % ring.length]] as const);

    const geometry = createGemGeometryFromTriangleSoup(soup);

    expect(geometry.facets).toHaveLength(1);
    expect(geometry.facets[0].triangleIndices).toHaveLength(6);
    expect(geometry.facets[0].boundaryEdges).toHaveLength(6);
    expect(geometry.facets[0].boundaryVertexIndices).toHaveLength(6);
  });
});

function v(x: number, y: number, z: number): Vec3 {
  return { x, y, z };
}

function cubeSoup(): TriangleSoup {
  const p = [
    v(0, 0, 0),
    v(1, 0, 0),
    v(1, 1, 0),
    v(0, 1, 0),
    v(0, 0, 1),
    v(1, 0, 1),
    v(1, 1, 1),
    v(0, 1, 1),
  ];

  return [
    [p[0], p[2], p[1]],
    [p[0], p[3], p[2]],
    [p[4], p[5], p[6]],
    [p[4], p[6], p[7]],
    [p[0], p[1], p[5]],
    [p[0], p[5], p[4]],
    [p[3], p[6], p[2]],
    [p[3], p[7], p[6]],
    [p[0], p[4], p[7]],
    [p[0], p[7], p[3]],
    [p[1], p[2], p[6]],
    [p[1], p[6], p[5]],
  ];
}
