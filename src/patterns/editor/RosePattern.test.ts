import { describe, expect, it } from 'vitest';
import { createRosePatternPrimitives } from './RosePattern';

describe('createRosePatternPrimitives', () => {
  it('creates centered, closed mathematical rose layers with the requested radius', () => {
    const primitives = createRosePatternPrimitives({ petals: 8, radius: 5, layers: 2, rotationDeg: 0 });

    expect(primitives).toHaveLength(2);
    expect(primitives.every((primitive) => primitive.closed)).toBe(true);
    expect(Math.hypot(primitives[1].points[0].x, primitives[1].points[0].y)).toBeCloseTo(5);
    expect(Math.max(...primitives[0].points.map((point) => Math.hypot(point.x, point.y)))).toBeCloseTo(2.5);
  });
});
