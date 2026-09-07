import { describe, expect, it } from 'vitest';
import { createPlaceholderGemGeometry } from './createPlaceholderGemGeometry';
import {
  calculateFacetBoundarySpanMm,
  calculateMeasuredLengthMm,
  calculateMeasurementScaleFactor,
  scaleGemGeometry,
} from './FacetMeasurement';

describe('FacetMeasurement', () => {
  it('converts screen distance to millimeters using the calibrated circle', () => {
    expect(calculateMeasuredLengthMm({ x: 10, y: 20 }, { x: 210, y: 20 }, 10, 100)).toBeCloseTo(20);
  });

  it('calculates the uniform scale required by a measured facet', () => {
    expect(calculateMeasurementScaleFactor(15, 10)).toBeCloseTo(1.5);
  });

  it('uniformly scales the mesh and preserves topology', () => {
    const geometry = createPlaceholderGemGeometry();
    const facet = geometry.facets[0];
    const originalSpan = calculateFacetBoundarySpanMm(geometry, facet);
    const scaled = scaleGemGeometry(geometry, 2.5);
    const scaledFacet = scaled.facets.find((candidate) => candidate.id === facet.id)!;

    expect(calculateFacetBoundarySpanMm(scaled, scaledFacet)).toBeCloseTo(originalSpan * 2.5);
    expect(scaled.triangles).toHaveLength(geometry.triangles.length);
    expect(scaled.facets).toHaveLength(geometry.facets.length);
    expect(scaled.boundingBox.center.x).toBeCloseTo(geometry.boundingBox.center.x);
    expect(scaled.boundingBox.center.y).toBeCloseTo(geometry.boundingBox.center.y);
    expect(scaled.boundingBox.center.z).toBeCloseTo(geometry.boundingBox.center.z);
  });
});
