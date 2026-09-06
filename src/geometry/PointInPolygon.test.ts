import { describe, expect, it } from 'vitest';
import { isPointInsideFacetLocal } from './PointInPolygon';

describe('isPointInsideFacetLocal', () => {
  const square = [
    { u: 0, v: 0 },
    { u: 2, v: 0 },
    { u: 2, v: 2 },
    { u: 0, v: 2 },
  ];

  it('returns true for an interior point', () => {
    expect(isPointInsideFacetLocal({ u: 1, v: 1 }, square)).toBe(true);
  });

  it('returns false for an exterior point', () => {
    expect(isPointInsideFacetLocal({ u: 3, v: 1 }, square)).toBe(false);
  });

  it('treats a point on an edge as inside', () => {
    expect(isPointInsideFacetLocal({ u: 1, v: 0 }, square)).toBe(true);
  });

  it('supports concave polygons', () => {
    const concave = [
      { u: 0, v: 0 },
      { u: 3, v: 0 },
      { u: 3, v: 3 },
      { u: 1.5, v: 1.5 },
      { u: 0, v: 3 },
    ];

    expect(isPointInsideFacetLocal({ u: 1, v: 1 }, concave)).toBe(true);
    expect(isPointInsideFacetLocal({ u: 1.5, v: 2.4 }, concave)).toBe(false);
  });
});
