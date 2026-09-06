import { describe, expect, it } from 'vitest';
import { createLinePrimitive } from '../model/PatternModel';
import { mirrorPrimitive, radialDuplicatePrimitives, transformPoint2D } from './transforms';

describe('2D pattern transforms', () => {
  it('moves, rotates and scales points', () => {
    const point = transformPoint2D(
      { x: 1, y: 0 },
      { translateX: 2, translateY: 3, rotationDeg: 90, scale: 2, center: { x: 0, y: 0 } },
    );

    expect(point.x).toBeCloseTo(2);
    expect(point.y).toBeCloseTo(5);
  });

  it('mirrors line primitives around X and Y axes', () => {
    const line = createLinePrimitive({ x: 1, y: 2 }, { x: 3, y: 4 });
    const mirrorX = mirrorPrimitive(line, 'x');
    const mirrorY = mirrorPrimitive(line, 'y');

    expect(mirrorX).toMatchObject({ start: { x: 1, y: -2 }, end: { x: 3, y: -4 } });
    expect(mirrorY).toMatchObject({ start: { x: -1, y: 2 }, end: { x: -3, y: 4 } });
  });

  it('radially duplicates a line at 0, 90, 180 and 270 degrees', () => {
    const line = createLinePrimitive({ x: 0, y: 0 }, { x: 1, y: 0 });
    const copies = radialDuplicatePrimitives([line], 4, { x: 0, y: 0 }, 360);

    expect(copies).toHaveLength(4);
    expect(copies[0]).toMatchObject({ end: { x: 1, y: 0 } });
    expect(copies[1]).toMatchObject({ end: { x: expect.closeTo(0), y: expect.closeTo(1) } });
    expect(copies[2]).toMatchObject({ end: { x: expect.closeTo(-1), y: expect.closeTo(0) } });
    expect(copies[3]).toMatchObject({ end: { x: expect.closeTo(0), y: expect.closeTo(-1) } });
  });
});
