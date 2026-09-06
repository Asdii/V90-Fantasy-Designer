import { describe, expect, it } from 'vitest';
import { createGemGeometryFromTriangleSoup } from './meshBuilder';
import { validateGemGeometry } from './GeometryValidation';

describe('validateGemGeometry', () => {
  it('accepts a finite closed manifold mesh', () => {
    const geometry = createTetrahedron();
    expect(validateGemGeometry(geometry)).toMatchObject({ vertexCount: 4, triangleCount: 4 });
  });

  it('rejects non-finite domain positions before rendering', () => {
    const geometry = createTetrahedron();
    const invalid = { ...geometry, vertices: [{ ...geometry.vertices[0], x: Number.NaN }, ...geometry.vertices.slice(1)] };
    expect(() => validateGemGeometry(invalid)).toThrow(/Non-finite/);
  });

  it('rejects out-of-range triangle indices', () => {
    const geometry = createTetrahedron();
    const invalid = {
      ...geometry,
      triangles: [{ ...geometry.triangles[0], a: 99 }, ...geometry.triangles.slice(1)],
    };
    expect(() => validateGemGeometry(invalid)).toThrow(/invalid vertex index/);
  });

  it('reports finite degenerate triangles without rejecting an otherwise usable kernel result', () => {
    const geometry = createTetrahedron();
    const withCollapsedVertex = {
      ...geometry,
      vertices: geometry.vertices.map((vertex, index) => index === 1 ? { ...geometry.vertices[0] } : vertex),
    };

    expect(validateGemGeometry(withCollapsedVertex).degenerateTriangleCount).toBeGreaterThan(0);
  });
});

function createTetrahedron() {
  const a = { x: 1, y: 1, z: 1 };
  const b = { x: -1, y: -1, z: 1 };
  const c = { x: -1, y: 1, z: -1 };
  const d = { x: 1, y: -1, z: -1 };
  return createGemGeometryFromTriangleSoup([
    [a, c, b],
    [a, b, d],
    [a, d, c],
    [b, c, d],
  ]);
}
