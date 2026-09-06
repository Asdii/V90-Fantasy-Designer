import { describe, expect, it } from 'vitest';
import type { FacetLocalGeometry } from '../../geometry/FacetLocalGeometry';
import { createCirclePrimitive, createLinePrimitive, createPolylinePrimitive, type DesignPattern } from '../model/PatternModel';
import {
  applyPatternPlacement,
  centerPatternPlacement,
  fitPatternPlacementToFacetBounds,
  clipPatternToFacet,
  patternPlacementToWorldCutPaths,
  type PatternPlacement,
} from './PatternPlacement';

describe('PatternPlacement', () => {
  it('applies offset to pattern points', () => {
    const point = applyPatternPlacement({ x: 0, y: 0 }, placement({ offsetX: 2, offsetY: 3 }));

    expect(point).toEqual({ u: 2, v: 3 });
  });

  it('applies rotation around the pattern origin', () => {
    const point = applyPatternPlacement({ x: 1, y: 0 }, placement({ rotationDeg: 90 }));

    expect(point.u).toBeCloseTo(0);
    expect(point.v).toBeCloseTo(1);
  });

  it('applies scale before offset', () => {
    const point = applyPatternPlacement({ x: 2, y: 3 }, placement({ scale: 2, offsetX: 1, offsetY: -1 }));

    expect(point.u).toBeCloseTo(5);
    expect(point.v).toBeCloseTo(5);
  });

  it('centers the fixed pattern origin while preserving scale and rotation', () => {
    const pattern = patternWithLine({ x: 2, y: 2 }, { x: 4, y: 4 });
    const centered = centerPatternPlacement(pattern, placement({ scale: 2, rotationDeg: 90 }));
    const placedOrigin = applyPatternPlacement({ x: 0, y: 0 }, centered);

    expect(placedOrigin.u).toBeCloseTo(0);
    expect(placedOrigin.v).toBeCloseTo(0);
    expect(centered.offsetX).toBe(0);
    expect(centered.offsetY).toBe(0);
    expect(centered.scale).toBe(2);
    expect(centered.rotationDeg).toBe(90);
  });

  it('fits a pattern without moving its fixed origin', () => {
    const pattern = patternWithLine({ x: 2, y: 2 }, { x: 6, y: 2 });
    const fitted = fitPatternPlacementToFacetBounds(pattern, placement({}), { width: 2, height: 4 });

    expect(fitted.scale).toBeCloseTo(0.95 / 6);
    expect(applyPatternPlacement({ x: 0, y: 0 }, fitted)).toEqual({ u: 0, v: 0 });
  });

  it('does not let distant primitives redefine the placement origin', () => {
    const pattern: DesignPattern = {
      id: 'mixed',
      name: 'mixed',
      primitives: [
        createLinePrimitive({ x: -1, y: 0 }, { x: 1, y: 0 }),
        createLinePrimitive({ x: 20, y: 5 }, { x: 22, y: 5 }),
      ],
    };

    const fitted = fitPatternPlacementToFacetBounds(pattern, placement({ offsetX: 8, offsetY: -3 }), localGeometry.bounds);

    expect(applyPatternPlacement({ x: 0, y: 0 }, fitted)).toEqual({ u: 0, v: 0 });
    expect(fitted.scale).toBeLessThan(0.05);
  });

  it('clips placed pattern segments to the facet polygon', () => {
    const pattern = patternWithLine({ x: -2, y: 0 }, { x: 2, y: 0 });
    const clipped = clipPatternToFacet(pattern, placement({}), squareBoundary);

    expect(clipped.insideSegments).toHaveLength(1);
    expect(clipped.outsideSegments).toHaveLength(2);
    expect(clipped.insideSegments[0].start.u).toBeCloseTo(-1);
    expect(clipped.insideSegments[0].end.u).toBeCloseTo(1);
  });

  it('extends straight cut paths beyond the whole facet before converting to world coordinates', () => {
    const pattern = patternWithLine({ x: -2, y: 0 }, { x: 2, y: 0 });
    const worldPaths = patternPlacementToWorldCutPaths(pattern, placement({}), localGeometry);

    expect(worldPaths).toHaveLength(1);
    expect(worldPaths[0].points[0].x).toBeLessThan(9);
    expect(worldPaths[0].points[1].x).toBeGreaterThan(11);
    expect(worldPaths[0].points[0]).toMatchObject({ y: 20, z: 30 });
    expect(worldPaths[0].points[1]).toMatchObject({ y: 20, z: 30 });
  });

  it('turns every polygon edge into an independent full-facet cut line', () => {
    const square: DesignPattern = {
      id: 'square',
      name: 'square',
      primitives: [
        createPolylinePrimitive(
          [
            { x: -0.25, y: -0.25 },
            { x: 0.25, y: -0.25 },
            { x: 0.25, y: 0.25 },
            { x: -0.25, y: 0.25 },
          ],
          true,
        ),
      ],
    };

    const worldPaths = patternPlacementToWorldCutPaths(square, placement({}), localGeometry);

    expect(worldPaths).toHaveLength(4);
    for (const path of worldPaths) {
      const [start, end] = path.points;
      expect(
        start.x < 9 || start.x > 11 || start.y < 19 || start.y > 21,
      ).toBe(true);
      expect(
        end.x < 9 || end.x > 11 || end.y < 19 || end.y > 21,
      ).toBe(true);
    }
  });

  it('keeps circles as curved paths instead of extending each tessellated chord', () => {
    const circle: DesignPattern = {
      id: 'circle',
      name: 'circle',
      primitives: [createCirclePrimitive({ x: 0, y: 0 }, 0.5)],
    };

    const worldPaths = patternPlacementToWorldCutPaths(circle, placement({}), localGeometry);

    expect(worldPaths.length).toBeGreaterThan(8);
    expect(worldPaths.flatMap((path) => path.points).every((point) => point.x >= 9.5 && point.x <= 10.5)).toBe(true);
    expect(worldPaths.flatMap((path) => path.points).every((point) => point.y >= 19.5 && point.y <= 20.5)).toBe(true);
  });
});

const squareBoundary = [
  { u: -1, v: -1 },
  { u: 1, v: -1 },
  { u: 1, v: 1 },
  { u: -1, v: 1 },
];

const localGeometry: FacetLocalGeometry = {
  frame: {
    origin: { x: 10, y: 20, z: 30 },
    uAxis: { x: 1, y: 0, z: 0 },
    vAxis: { x: 0, y: 1, z: 0 },
    normal: { x: 0, y: 0, z: 1 },
  },
  boundary: squareBoundary,
  bounds: { minU: -1, maxU: 1, minV: -1, maxV: 1, width: 2, height: 2 },
};

function placement(partial: Partial<PatternPlacement>): PatternPlacement {
  return {
    facetId: 0,
    offsetX: 0,
    offsetY: 0,
    rotationDeg: 0,
    scale: 1,
    ...partial,
  };
}

function patternWithLine(start: { readonly x: number; readonly y: number }, end: { readonly x: number; readonly y: number }): DesignPattern {
  return {
    id: 'pattern',
    name: 'pattern',
    primitives: [createLinePrimitive(start, end)],
  };
}
