import { describe, expect, it } from 'vitest';
import { constrainMeasurementPoint } from './FacetMeasurementSession';

describe('FacetMeasurementSession', () => {
  it('constrains a mostly horizontal measurement to the horizontal axis', () => {
    expect(constrainMeasurementPoint({ x: 10, y: 20 }, { x: 90, y: 35 })).toEqual({ x: 90, y: 20 });
  });

  it('constrains a mostly vertical measurement to the vertical axis', () => {
    expect(constrainMeasurementPoint({ x: 10, y: 20 }, { x: 22, y: 90 })).toEqual({ x: 10, y: 90 });
  });
});
