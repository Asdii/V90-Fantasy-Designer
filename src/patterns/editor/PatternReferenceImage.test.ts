import { describe, expect, it } from 'vitest';
import { createPatternReferenceImage } from './PatternReferenceImage';

describe('createPatternReferenceImage', () => {
  it('preserves the calibrated physical scale and image offset', () => {
    const image = createPatternReferenceImage({
      dataUrl: 'data:image/png;base64,test',
      naturalWidth: 1000,
      naturalHeight: 500,
      viewportWidth: 800,
      viewportHeight: 600,
      imageZoom: 2,
      imagePan: { x: 40, y: -20 },
      referenceDiameterMm: 10,
      referenceDiameterPx: 200,
    });

    expect(image.mmPerPixel).toBeCloseTo(0.08);
    expect(image.center).toEqual({ x: 2, y: 1 });
    expect(image.rotationDeg).toBe(0);
  });

  it('preserves photo rotation for the pattern overlay', () => {
    const image = createPatternReferenceImage({
      dataUrl: 'data:image/png;base64,test',
      naturalWidth: 100,
      naturalHeight: 100,
      viewportWidth: 500,
      viewportHeight: 500,
      imageZoom: 1,
      imagePan: { x: 0, y: 0 },
      imageRotationDeg: 27,
      referenceDiameterMm: 10,
      referenceDiameterPx: 180,
    });
    expect(image.rotationDeg).toBe(27);
  });
});
