import { describe, expect, it } from 'vitest';
import { calculateFacetAngleFromHorizontal, calculateWheelTierGuide } from './WheelTierGuide';

describe('WheelTierGuide', () => {
  it('calculates the circular runout of a physical wheel', () => {
    const guide = calculateWheelTierGuide({
      depthMm: 0.1,
      wheelDiameterMm: 20,
      tierAngleDeg: 45,
      facetNormal: { x: 0, y: 1, z: 0 },
    });

    expect(guide.runoutAlongFacetMm).toBeCloseTo(Math.sqrt(1.99));
    expect(guide.estimatedTierAxialHeightMm).toBeCloseTo(guide.runoutAlongFacetMm);
    expect(guide.estimatedTierSurfaceWidthMm).toBeCloseTo(guide.runoutAlongFacetMm * Math.SQRT2);
    expect(guide.depthWithinWheelRadius).toBe(true);
  });

  it('projects the wheel runout using the selected facet inclination', () => {
    const guide = calculateWheelTierGuide({
      depthMm: 0.1,
      wheelDiameterMm: 20,
      tierAngleDeg: 45,
      facetNormal: { x: 0, y: 0.5, z: Math.sqrt(0.75) },
    });

    expect(guide.facetAngleDeg).toBeCloseTo(60);
    expect(guide.radialProjectionMm).toBeCloseTo(guide.runoutAlongFacetMm * 0.5);
  });

  it('reports depths that pass the wheel center', () => {
    const guide = calculateWheelTierGuide({ depthMm: 6, wheelDiameterMm: 10, tierAngleDeg: 45 });

    expect(guide.depthWithinWheelRadius).toBe(false);
  });
});

describe('calculateFacetAngleFromHorizontal', () => {
  it('returns zero for a horizontal facet and ninety for a vertical facet', () => {
    expect(calculateFacetAngleFromHorizontal({ x: 0, y: 1, z: 0 })).toBeCloseTo(0);
    expect(calculateFacetAngleFromHorizontal({ x: 1, y: 0, z: 0 })).toBeCloseTo(90);
  });
});
