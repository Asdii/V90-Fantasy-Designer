import { describe, expect, it } from 'vitest';
import { createCenteredRectanglePrimitive, createRectanglePrimitive } from './Rectangle';

describe('createRectanglePrimitive', () => {
  it('creates a closed four-corner polyline from opposite corners', () => {
    const rectangle = createRectanglePrimitive({ x: -1, y: -2 }, { x: 3, y: 4 });

    expect(rectangle.closed).toBe(true);
    expect(rectangle.points).toEqual([
      { x: -1, y: -2 },
      { x: 3, y: -2 },
      { x: 3, y: 4 },
      { x: -1, y: 4 },
    ]);
  });

  it('rotates a centered rectangle without losing its closed fourth edge', () => {
    const rectangle = createCenteredRectanglePrimitive({ x: 0, y: 0 }, { x: 2, y: 1 }, 90);

    expect(rectangle.points).toHaveLength(4);
    expect(rectangle.closed).toBe(true);
    expect(rectangle.points[0]).toEqual(expect.objectContaining({ x: expect.closeTo(1), y: expect.closeTo(-2) }));
  });
});
