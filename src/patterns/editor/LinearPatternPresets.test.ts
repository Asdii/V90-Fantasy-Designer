import { describe, expect, it } from 'vitest';
import { createGeometricStarPrimitive, createRadialBurstPrimitives } from './LinearPatternPresets';

describe('linear pattern presets', () => {
  it('creates an eight-point star using only straight polyline edges', () => {
    const star = createGeometricStarPrimitive({ points: 8, outerRadius: 4, innerRadius: 2, rotationDeg: 0 });

    expect(star.type).toBe('polyline');
    expect(star.closed).toBe(true);
    expect(star.points).toHaveLength(16);
    expect(star.points[0]).toEqual({ x: 4, y: 0 });
    expect(Math.hypot(star.points[1].x, star.points[1].y)).toBeCloseTo(2);
  });

  it('creates a radial burst as independent straight lines', () => {
    const radials = createRadialBurstPrimitives({ count: 4, outerRadius: 5, innerRadius: 1, rotationDeg: 0 });

    expect(radials).toHaveLength(4);
    expect(radials.every((primitive) => primitive.type === 'line')).toBe(true);
    expect(radials[0].start).toEqual({ x: 1, y: 0 });
    expect(radials[0].end).toEqual({ x: 5, y: 0 });
    expect(radials[1].end.x).toBeCloseTo(0);
    expect(radials[1].end.y).toBeCloseTo(5);
  });
});
