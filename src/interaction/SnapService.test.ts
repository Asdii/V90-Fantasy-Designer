import { describe, expect, it } from 'vitest';
import { snapPoint } from './SnapService';

describe('SnapService', () => {
  it('snaps a raw point near origin to exact origin', () => {
    const snapped = snapPoint(
      { u: 0.12, v: -0.08 },
      [{ point: { u: 0, v: 0 }, screenDistancePx: 4, priority: 3 }],
      'off',
      true,
    );

    expect(snapped).toEqual({ u: 0, v: 0 });
  });

  it('prioritizes existing endpoints before origin', () => {
    const snapped = snapPoint(
      { u: 0.1, v: 0.1 },
      [
        { point: { u: 0, v: 0 }, screenDistancePx: 2, priority: 3 },
        { point: { u: 2, v: 2 }, screenDistancePx: 3, priority: 1 },
      ],
      'off',
      true,
    );

    expect(snapped).toEqual({ u: 2, v: 2 });
  });

  it('snaps to grid when no higher priority candidate is close enough', () => {
    const snapped = snapPoint({ u: 1.24, v: -0.76 }, [], '0.5', true);

    expect(snapped).toEqual({ u: 1, v: -1 });
  });
});
