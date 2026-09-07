import { describe, expect, it } from 'vitest';
import { createCirclePrimitive, createLinePrimitive, type DesignPattern } from '../model/PatternModel';
import { snapEditorPoint, snapRegularShapePoint } from './SnapEngine';

describe('snapEditorPoint', () => {
  it('snaps to line intersections before grid', () => {
    const pattern: DesignPattern = {
      id: 'p',
      name: 'p',
      primitives: [
        createLinePrimitive({ x: -1, y: 0 }, { x: 1, y: 0 }),
        createLinePrimitive({ x: 0, y: -1 }, { x: 0, y: 1 }),
      ],
    };

    const result = snapEditorPoint({ x: 0.03, y: -0.02 }, pattern, {
      enabled: true,
      gridSpacing: 1,
      snapDistanceWorld: 0.1,
    });

    expect(result.source).toBe('intersection');
    expect(result.point).toEqual({ x: 0, y: 0 });
  });

  it('snaps to circle centers', () => {
    const pattern: DesignPattern = {
      id: 'p',
      name: 'p',
      primitives: [createCirclePrimitive({ x: 2, y: 3 }, 1)],
    };

    const result = snapEditorPoint({ x: 2.02, y: 2.98 }, pattern, {
      enabled: true,
      gridSpacing: 1,
      snapDistanceWorld: 0.1,
    });

    expect(result.source).toBe('center');
    expect(result.point).toEqual({ x: 2, y: 3 });
  });
});

describe('snapRegularShapePoint', () => {
  it('reuses the radius of a concentric regular shape without moving its center', () => {
    const pattern = {
      id: 'pattern',
      name: 'pattern',
      primitives: [{
        id: 'triangle',
        type: 'polyline' as const,
        role: 'pattern' as const,
        closed: true,
        points: [
          { x: 0, y: 5 },
          { x: -4.330127, y: -2.5 },
          { x: 4.330127, y: -2.5 },
        ],
      }],
    };

    const point = snapRegularShapePoint({ x: 0.08, y: -4.94 }, pattern, {
      center: { x: 0, y: 0 },
      enabled: true,
      gridSpacing: 1,
      snapDistanceWorld: 0.2,
      angleStepDeg: 15,
    });

    expect(point.x).toBeCloseTo(0, 6);
    expect(point.y).toBeCloseTo(-5, 6);
  });

  it('exposes closed polyline centers to normal snapping', () => {
    const pattern = {
      id: 'pattern',
      name: 'pattern',
      primitives: [{
        id: 'triangle',
        type: 'polyline' as const,
        role: 'pattern' as const,
        closed: true,
        points: [{ x: 0, y: 4 }, { x: -3, y: -2 }, { x: 3, y: -2 }],
      }],
    };
    const result = snapEditorPoint({ x: 0.04, y: -0.03 }, pattern, {
      enabled: true,
      gridSpacing: 1,
      snapDistanceWorld: 0.1,
    });
    expect(result.source).toBe('center');
    expect(result.point).toEqual({ x: 0, y: 0 });
  });
});
