import { describe, expect, it } from 'vitest';
import { createCirclePrimitive, createLinePrimitive, type DesignPattern } from '../model/PatternModel';
import { snapEditorPoint } from './SnapEngine';

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
