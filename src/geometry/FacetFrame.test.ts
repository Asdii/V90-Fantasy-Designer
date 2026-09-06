import { describe, expect, it } from 'vitest';
import type { Vec3 } from './GemGeometry';
import { localToWorld, worldToLocal } from './CoordinateTransforms';
import { createFacetFrame } from './FacetFrame';
import { createFacetLocalGeometry } from './FacetLocalGeometry';
import { createGemGeometryFromTriangleSoup, type TriangleSoup } from './meshBuilder';
import { cross, dot, length, normalize } from './vectorMath';

const EPSILON = 1e-9;

describe('FacetFrame', () => {
  it('creates an orthonormal basis with U cross V equal to N', () => {
    const geometry = createGemGeometryFromTriangleSoup(squareSoup());
    const frame = createFacetFrame(geometry, geometry.facets[0]);

    expectBasis(frame.uAxis, frame.vAxis, frame.normal);
  });

  it('maps local origin to world origin point', () => {
    const geometry = createGemGeometryFromTriangleSoup(squareSoup());
    const frame = createFacetFrame(geometry, geometry.facets[0]);

    expectVec(localToWorld(frame, 0, 0), frame.origin);
  });

  it('maps world origin point to local zero coordinates', () => {
    const geometry = createGemGeometryFromTriangleSoup(squareSoup());
    const frame = createFacetFrame(geometry, geometry.facets[0]);
    const local = worldToLocal(frame, frame.origin);

    expect(local.u).toBeCloseTo(0);
    expect(local.v).toBeCloseTo(0);
    expect(local.n).toBeCloseTo(0);
  });

  it('round-trips local coordinates through world space', () => {
    const geometry = createGemGeometryFromTriangleSoup(squareSoup());
    const frame = createFacetFrame(geometry, geometry.facets[0]);
    const world = localToWorld(frame, 2.3, -1.7);
    const local = worldToLocal(frame, world);

    expect(local.u).toBeCloseTo(2.3);
    expect(local.v).toBeCloseTo(-1.7);
    expect(local.n).toBeCloseTo(0);
  });

  it('keeps boundary vertices on the local plane', () => {
    const geometry = createGemGeometryFromTriangleSoup(squareSoup());
    const facet = geometry.facets[0];
    const localGeometry = createFacetLocalGeometry(geometry, facet);

    for (const vertexIndex of facet.boundaryVertexIndices) {
      expect(Math.abs(worldToLocal(localGeometry.frame, geometry.vertices[vertexIndex]).n)).toBeLessThan(1e-8);
    }
    expect(localGeometry.bounds.width).toBeGreaterThan(0);
    expect(localGeometry.bounds.height).toBeGreaterThan(0);
  });

  it('is deterministic for repeated construction', () => {
    const geometry = createGemGeometryFromTriangleSoup(hexagonSoup());
    const first = createFacetFrame(geometry, geometry.facets[0]);
    const second = createFacetFrame(geometry, geometry.facets[0]);

    expectVec(first.uAxis, second.uAxis);
    expectVec(first.vAxis, second.vAxis);
    expectVec(first.normal, second.normal);
  });

  it('handles horizontal upward and downward normals', () => {
    const upward = createGemGeometryFromTriangleSoup([[v(0, 0, 0), v(1, 0, 0), v(0, 1, 0)]]);
    const downward = createGemGeometryFromTriangleSoup([[v(0, 0, 0), v(0, 1, 0), v(1, 0, 0)]]);

    expectBasisForGeometry(upward);
    expectBasisForGeometry(downward);
  });

  it('handles vertical normals', () => {
    const normalX = createGemGeometryFromTriangleSoup([[v(0, 0, 0), v(0, 1, 0), v(0, 0, 1)]]);
    const normalY = createGemGeometryFromTriangleSoup([[v(0, 0, 0), v(0, 0, 1), v(1, 0, 0)]]);

    expectBasisForGeometry(normalX);
    expectBasisForGeometry(normalY);
  });

  it('handles an arbitrary normal', () => {
    const arbitrary = createGemGeometryFromTriangleSoup([[v(1, 0, 0), v(0, 1, 0), v(0, 0, 1)]]);

    expectBasisForGeometry(arbitrary);
    expectVec(arbitrary.facets[0].normal, normalize(v(1, 1, 1)));
  });
});

function expectBasisForGeometry(geometry: ReturnType<typeof createGemGeometryFromTriangleSoup>) {
  const frame = createFacetFrame(geometry, geometry.facets[0]);
  expectBasis(frame.uAxis, frame.vAxis, frame.normal);
}

function expectBasis(u: Vec3, vAxis: Vec3, n: Vec3) {
  expect(length(u)).toBeCloseTo(1);
  expect(length(vAxis)).toBeCloseTo(1);
  expect(length(n)).toBeCloseTo(1);
  expect(dot(u, vAxis)).toBeCloseTo(0);
  expect(dot(u, n)).toBeCloseTo(0);
  expect(dot(vAxis, n)).toBeCloseTo(0);
  expectVec(cross(u, vAxis), n);
}

function expectVec(actual: Vec3, expected: Vec3) {
  expect(actual.x).toBeCloseTo(expected.x, 8);
  expect(actual.y).toBeCloseTo(expected.y, 8);
  expect(actual.z).toBeCloseTo(expected.z, 8);
  expect(length({ x: actual.x - expected.x, y: actual.y - expected.y, z: actual.z - expected.z })).toBeLessThan(
    EPSILON,
  );
}

function squareSoup(): TriangleSoup {
  return [
    [v(0, 0, 0), v(2, 0, 0), v(2, 2, 0)],
    [v(0, 0, 0), v(2, 2, 0), v(0, 2, 0)],
  ];
}

function hexagonSoup(): TriangleSoup {
  const center = v(0, 0, 0);
  const ring = Array.from({ length: 6 }, (_, index) => {
    const angle = (index / 6) * Math.PI * 2;
    return v(Math.cos(angle), Math.sin(angle), 0);
  });
  return ring.map((point, index) => [center, point, ring[(index + 1) % ring.length]]);
}

function v(x: number, y: number, z: number): Vec3 {
  return { x, y, z };
}
