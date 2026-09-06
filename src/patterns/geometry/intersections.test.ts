import { describe, expect, it } from 'vitest';
import { createLinePrimitive } from '../model/PatternModel';
import { intersectLineSegments } from './intersections';

describe('intersectLineSegments', () => {
  it('finds the crossing point of two mathematical line segments', () => {
    const horizontal = createLinePrimitive({ x: -1, y: 0 }, { x: 1, y: 0 });
    const vertical = createLinePrimitive({ x: 0, y: -1 }, { x: 0, y: 1 });

    const intersection = intersectLineSegments(horizontal, vertical);

    expect(intersection?.x).toBeCloseTo(0);
    expect(intersection?.y).toBeCloseTo(0);
  });
});
