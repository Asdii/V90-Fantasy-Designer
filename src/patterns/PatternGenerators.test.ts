import { describe, expect, it } from 'vitest';
import { generatePattern } from './PatternGenerators';

describe('PatternGenerators', () => {
  it('generates regular polygons as closed segment loops', () => {
    const pattern = generatePattern('regularPolygon', { sides: 6, radius: 2, rotationDeg: 0 });

    expect(pattern.segments).toHaveLength(6);
    expect(uniqueEndpoints(pattern)).toBe(6);
  });

  it('generates alternating vertices for inner-radius stars', () => {
    const pattern = generatePattern('star', { points: 8, outerRadius: 3, innerRadius: 1.5, rotationDeg: 0 });

    expect(pattern.segments).toHaveLength(16);
    expect(pattern.segments[0].start.u).toBeCloseTo(3);
    expect(Math.hypot(pattern.segments[0].end.u, pattern.segments[0].end.v)).toBeCloseTo(1.5);
  });

  it('generates regular star polygons using the requested step', () => {
    const pattern = generatePattern('starPolygon', { points: 5, step: 2, radius: 1, rotationDeg: 0 });

    expect(pattern.segments).toHaveLength(5);
    expect(pattern.segments[0].start.u).toBeCloseTo(1);
    expect(pattern.segments[0].end.u).toBeCloseTo(Math.cos((144 * Math.PI) / 180));
    expect(pattern.segments[0].end.v).toBeCloseTo(Math.sin((144 * Math.PI) / 180));
  });

  it('generates radial lines', () => {
    const pattern = generatePattern('radialLines', {
      count: 12,
      innerRadius: 0,
      outerRadius: 3,
      rotationDeg: 0,
    });

    expect(pattern.segments).toHaveLength(12);
    expect(pattern.segments.every((segment) => segment.start.u === 0 && segment.start.v === 0)).toBe(true);
  });

  it('generates concentric polygons and circles', () => {
    const polygons = generatePattern('concentricPolygons', {
      sides: 8,
      count: 3,
      innerRadius: 1,
      outerRadius: 3,
      rotationDeg: 0,
    });
    const circles = generatePattern('concentricCircles', { count: 2, innerRadius: 1, outerRadius: 2 });

    expect(polygons.segments).toHaveLength(24);
    expect(circles.segments).toHaveLength(128);
  });

  it('generates a simple rosette from radial point connections', () => {
    const pattern = generatePattern('simpleRosette', {
      order: 12,
      outerRadius: 3,
      innerRadius: 1.2,
      rotationDeg: 0,
      connectionStep: 5,
    });

    expect(pattern.segments).toHaveLength(36);
    expect(pattern.generated?.generatorType).toBe('simpleRosette');
  });
});

function uniqueEndpoints(pattern: ReturnType<typeof generatePattern>) {
  const keys = new Set<string>();
  for (const segment of pattern.segments) {
    keys.add(`${segment.start.u.toFixed(6)},${segment.start.v.toFixed(6)}`);
    keys.add(`${segment.end.u.toFixed(6)},${segment.end.v.toFixed(6)}`);
  }
  return keys.size;
}
