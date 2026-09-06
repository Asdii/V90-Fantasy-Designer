import { describe, expect, it } from 'vitest';
import type { Vec3 } from '../geometry/GemGeometry';
import { dot, length, normalize, subtract } from '../geometry/vectorMath';
import type { WorldCutPath } from '../patterns/placement/PatternPlacement';
import { calculateVGrooveDimensions } from './VGrooveSettings';
import { generateVGroovePreviewGeometry } from './VGrooveGenerator';

describe('VGrooveGenerator', () => {
  it('calculates width from a full 90 degree included angle', () => {
    const dimensions = calculateVGrooveDimensions({ includedAngleDeg: 90, depthMm: 1 });

    expect(dimensions.halfAngleDeg).toBeCloseTo(45);
    expect(dimensions.halfWidthMm).toBeCloseTo(1);
    expect(dimensions.widthMm).toBeCloseTo(2);
  });

  it('calculates width from a full 60 degree included angle', () => {
    const dimensions = calculateVGrooveDimensions({ includedAngleDeg: 60, depthMm: 1 });

    expect(dimensions.halfWidthMm).toBeCloseTo(Math.tan(Math.PI / 6));
    expect(dimensions.widthMm).toBeCloseTo(1.154700538);
  });

  it('builds a horizontal triangular groove with depth toward negative facet normal', () => {
    const groove = generateVGroovePreviewGeometry([path([{ x: -2, y: 0, z: 0 }, { x: 2, y: 0, z: 0 }])], normal(0, 0, 1), {
      includedAngleDeg: 90,
      depthMm: 1,
    });

    expect(groove.vertices).toHaveLength(6);
    expect(groove.triangles).toHaveLength(6);
    expect(groove.vertices.some((vertex) => Math.abs(vertex.z + 1) < 1e-9)).toBe(true);
    expect(groove.vertices.some((vertex) => Math.abs(Math.abs(vertex.y) - 1) < 1e-9)).toBe(true);
  });

  it('places every bottom vertex at z = -depth for a z=0 facet with +Z outward normal', () => {
    const groove = generateVGroovePreviewGeometry([path([{ x: -2, y: 0, z: 0 }, { x: 2, y: 0, z: 0 }])], normal(0, 0, 1), {
      includedAngleDeg: 90,
      depthMm: 1,
    });

    expect(groove.vertices[1].z).toBeCloseTo(-1);
    expect(groove.vertices[4].z).toBeCloseTo(-1);
    expect(groove.vertices.every((vertex) => vertex.z <= 0)).toBe(true);
  });

  it('uses negative facet normal as the physical depth direction on an inclined facet', () => {
    const n = normalize({ x: 1, y: 1, z: 1 });
    const groove = generateVGroovePreviewGeometry([path([{ x: 0, y: 0, z: 0 }, { x: 1, y: -1, z: 0 }])], { normal: n }, {
      includedAngleDeg: 90,
      depthMm: 0.7,
    });

    const startBottom = groove.vertices[1];
    const depthVector = subtract({ x: 0, y: 0, z: 0 }, startBottom);

    expect(dot(depthVector, n)).toBeCloseTo(0.7);
    expect(length(depthVector)).toBeCloseTo(0.7);
  });

  it('produces the same point set for reversed path direction', () => {
    const settings = { includedAngleDeg: 90, depthMm: 1 };
    const forward = generateVGroovePreviewGeometry([path([{ x: -2, y: 0, z: 0 }, { x: 2, y: 0, z: 0 }])], normal(0, 0, 1), settings);
    const reverse = generateVGroovePreviewGeometry([path([{ x: 2, y: 0, z: 0 }, { x: -2, y: 0, z: 0 }])], normal(0, 0, 1), settings);

    expect(pointSet(reverse.vertices)).toEqual(pointSet(forward.vertices));
  });

  it('creates one prism per valid path segment', () => {
    const groove = generateVGroovePreviewGeometry(
      [
        path([
          { x: 0, y: 0, z: 0 },
          { x: 1, y: 0, z: 0 },
          { x: 1, y: 1, z: 0 },
        ]),
      ],
      normal(0, 0, 1),
      { includedAngleDeg: 60, depthMm: 0.5 },
    );

    expect(groove.triangles).toHaveLength(12);
    expect(groove.centerLines).toHaveLength(1);
  });

  it('creates a surface guide with the calculated groove opening', () => {
    const groove = generateVGroovePreviewGeometry(
      [path([{ x: -2, y: 0, z: 0 }, { x: 2, y: 0, z: 0 }])],
      normal(0, 0, 1),
      { includedAngleDeg: 90, depthMm: 0.5 },
    );

    expect(groove.surfaceGuides).toHaveLength(1);
    const openingY = [groove.surfaceGuides![0].startLeft.y, groove.surfaceGuides![0].startRight.y].sort((a, b) => a - b);
    expect(openingY[0]).toBeCloseTo(-0.5);
    expect(openingY[1]).toBeCloseTo(0.5);
    expect(groove.outwardNormal).toEqual({ x: 0, y: 0, z: 1 });
    expect(groove.depthMm).toBeCloseTo(0.5);
  });
});

function path(points: readonly Vec3[]): WorldCutPath {
  return { points };
}

function normal(x: number, y: number, z: number) {
  return { normal: { x, y, z } };
}

function pointSet(points: readonly Vec3[]) {
  return points.map((point) => `${round(point.x)},${round(point.y)},${round(point.z)}`).sort();
}

function round(value: number) {
  return Math.round(value * 1e9) / 1e9;
}
