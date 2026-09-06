import { describe, expect, it } from 'vitest';
import { createGemGeometryFromTriangleSoup } from '../geometry/meshBuilder';
import { createSegment, identityPatternTransform } from './Pattern';
import {
  circularArraySegments,
  createRectangleSegments,
  inverseTransformPoint,
  mirrorSegments,
  segmentAngleDegrees,
  segmentLength,
  transformPoint,
} from './PatternGeometry';

describe('PatternGeometry', () => {
  it('calculates segment length and angle', () => {
    const segment = createSegment({ u: -1, v: 0 }, { u: 2, v: 3 });

    expect(segmentLength(segment)).toBeCloseTo(Math.sqrt(18));
    expect(segmentAngleDegrees(segment)).toBeCloseTo(45);
  });

  it('creates axis-aligned rectangle segments in local U/V coordinates', () => {
    const segments = createRectangleSegments({ u: -1, v: -1 }, { u: 1, v: 1 });

    expect(segments.map((segment) => [segment.start, segment.end])).toEqual([
      [{ u: -1, v: -1 }, { u: 1, v: -1 }],
      [{ u: 1, v: -1 }, { u: 1, v: 1 }],
      [{ u: 1, v: 1 }, { u: -1, v: 1 }],
      [{ u: -1, v: 1 }, { u: -1, v: -1 }],
    ]);
  });

  it('keeps Pattern edits independent from GemGeometry vertices and triangles', () => {
    const geometry = createGemGeometryFromTriangleSoup([
      [{ x: 0, y: 0, z: 0 }, { x: 1, y: 0, z: 0 }, { x: 0, y: 1, z: 0 }],
    ]);
    const verticesBefore = JSON.stringify(geometry.vertices);
    const trianglesBefore = JSON.stringify(geometry.triangles);

    const pattern = {
      id: 'p',
      name: 'Pattern',
      segments: [createSegment({ u: 0, v: 0 }, { u: 1, v: 1 })],
      transform: identityPatternTransform,
    };
    const changedPattern = { ...pattern, segments: [...pattern.segments, createSegment({ u: 1, v: 0 }, { u: 0, v: 1 })] };

    expect(changedPattern.segments).toHaveLength(2);
    expect(JSON.stringify(geometry.vertices)).toBe(verticesBefore);
    expect(JSON.stringify(geometry.triangles)).toBe(trianglesBefore);
  });

  it('rotates pattern coordinates through PatternTransform', () => {
    const transformed = transformPoint(
      { u: 1, v: 0 },
      { offsetU: 0, offsetV: 0, rotationDeg: 90, scale: 1 },
    );

    expect(transformed.u).toBeCloseTo(0);
    expect(transformed.v).toBeCloseTo(1);
  });

  it('round-trips through transform and inverse transform', () => {
    const transform = { offsetU: 2, offsetV: -1, rotationDeg: 37, scale: 1.8 };
    const point = { u: -0.7, v: 2.25 };
    const roundTrip = inverseTransformPoint(transformPoint(point, transform), transform);

    expect(roundTrip.u).toBeCloseTo(point.u);
    expect(roundTrip.v).toBeCloseTo(point.v);
  });

  it('mirrors segments around local U and V axes', () => {
    const segment = createSegment({ u: 1, v: 2 }, { u: -3, v: 4 });

    expect(mirrorSegments([segment], 'u')[0]).toMatchObject({
      start: { u: 1, v: -2 },
      end: { u: -3, v: -4 },
    });
    expect(mirrorSegments([segment], 'v')[0]).toMatchObject({
      start: { u: -1, v: 2 },
      end: { u: 3, v: 4 },
    });
  });

  it('creates circular arrays from selected segments', () => {
    const segment = createSegment({ u: 0, v: 0 }, { u: 1, v: 0 });
    const array = circularArraySegments([segment], 4, { u: 0, v: 0 }, 360, 0);

    expect(array).toHaveLength(4);
    expect(array[0].end).toMatchObject({ u: 1, v: 0 });
    expect(array[1].end.u).toBeCloseTo(0);
    expect(array[1].end.v).toBeCloseTo(1);
    expect(array[2].end.u).toBeCloseTo(-1);
    expect(array[2].end.v).toBeCloseTo(0);
    expect(array[3].end.u).toBeCloseTo(0);
    expect(array[3].end.v).toBeCloseTo(-1);
  });
});
