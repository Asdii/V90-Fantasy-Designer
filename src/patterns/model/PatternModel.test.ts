import { describe, expect, it } from 'vitest';
import { createArcPrimitive, createCirclePrimitive, createLinePrimitive } from './PatternModel';

describe('Pattern primitives', () => {
  it('stores line endpoints mathematically', () => {
    const line = createLinePrimitive({ x: -1, y: 2 }, { x: 3, y: 4 });

    expect(line.type).toBe('line');
    expect(line.start).toEqual({ x: -1, y: 2 });
    expect(line.end).toEqual({ x: 3, y: 4 });
    expect(line.role).toBe('pattern');
  });

  it('stores circle center and radius mathematically', () => {
    const circle = createCirclePrimitive({ x: 2, y: -3 }, 5);

    expect(circle.type).toBe('circle');
    expect(circle.center).toEqual({ x: 2, y: -3 });
    expect(circle.radius).toBe(5);
  });

  it('stores arc radius and angles mathematically', () => {
    const arc = createArcPrimitive({ x: 0, y: 0 }, 2.5, 15, 120);

    expect(arc.type).toBe('arc');
    expect(arc.radius).toBe(2.5);
    expect(arc.startAngleDeg).toBe(15);
    expect(arc.endAngleDeg).toBe(120);
  });
});
