import { describe, expect, it } from 'vitest';
import type { GemGeometry, Triangle, Vec3 } from '../../geometry/GemGeometry';
import { triangleNormal } from '../../geometry/vectorMath';
import { OpticalBVH } from './OpticalBVH';
import { createStudioOpticalEnvironment, OpticalTracer } from './OpticalTracer';

describe('Optical tracing', () => {
  it('BVH returns the nearest triangle hit', () => {
    const geometry = twoPlaneGeometry();
    const bvh = new OpticalBVH(geometry);
    const hit = bvh.intersect({ origin: { x: 0, y: 0, z: 10 }, direction: { x: 0, y: 0, z: -1 } });

    expect(hit?.triangleIndex).toBe(0);
    expect(hit?.point.z).toBeCloseTo(1);
  });

  it('continues through multiple optical surface interactions', () => {
    const tracer = new OpticalTracer(twoPlaneGeometry());
    const result = tracer.trace(
      { origin: { x: 0, y: 0, z: 10 }, direction: { x: 0, y: 0, z: -1 } },
      { refractiveIndex: 1.544, color: '#ffffff' },
      createStudioOpticalEnvironment('white'),
      { maxBounces: 6, rayEpsilonMm: 1e-5 },
    );

    expect(result.bounces).toBeGreaterThanOrEqual(2);
    expect(result.exited).toBe(true);
  });
});

function twoPlaneGeometry(): Pick<GemGeometry, 'vertices' | 'triangles'> {
  const vertices = [
    { x: -1, y: -1, z: 1 },
    { x: 1, y: -1, z: 1 },
    { x: 1, y: 1, z: 1 },
    { x: -1, y: -1, z: 0 },
    { x: 1, y: 1, z: 0 },
    { x: 1, y: -1, z: 0 },
  ];
  return {
    vertices,
    triangles: [
      triangle(0, 2, 1, vertices),
      triangle(3, 4, 5, vertices),
    ],
  };
}

function triangle(a: number, b: number, c: number, vertices: readonly Vec3[]): Triangle {
  return { a, b, c, normal: triangleNormal(vertices[a], vertices[b], vertices[c]) };
}
