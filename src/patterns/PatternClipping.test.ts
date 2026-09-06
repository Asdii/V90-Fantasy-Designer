import { describe, expect, it } from 'vitest';
import { createSegment } from './Pattern';
import { clipSegmentToFacetPolygon } from './PatternClipping';

describe('clipSegmentToFacetPolygon', () => {
  const square = [
    { u: -1, v: -1 },
    { u: 1, v: -1 },
    { u: 1, v: 1 },
    { u: -1, v: 1 },
  ];

  it('keeps fully interior segments inside', () => {
    const result = clipSegmentToFacetPolygon(createSegment({ u: -0.5, v: 0 }, { u: 0.5, v: 0 }), square);

    expect(result.inside).toHaveLength(1);
    expect(result.outside).toHaveLength(0);
  });

  it('separates inside and outside portions of crossing segments', () => {
    const result = clipSegmentToFacetPolygon(createSegment({ u: -2, v: 0 }, { u: 2, v: 0 }), square);

    expect(result.inside).toHaveLength(1);
    expect(result.outside).toHaveLength(2);
    expect(result.inside[0].start.u).toBeCloseTo(-1);
    expect(result.inside[0].end.u).toBeCloseTo(1);
  });

  it('classifies fully exterior segments outside', () => {
    const result = clipSegmentToFacetPolygon(createSegment({ u: -2, v: 2 }, { u: 2, v: 2 }), square);

    expect(result.inside).toHaveLength(0);
    expect(result.outside).toHaveLength(1);
  });
});
