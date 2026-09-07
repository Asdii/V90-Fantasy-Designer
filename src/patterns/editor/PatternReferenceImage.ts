import type { Vec2 } from '../model/PatternModel';

export interface PatternReferenceImage {
  readonly id: string;
  readonly dataUrl: string;
  readonly naturalWidth: number;
  readonly naturalHeight: number;
  readonly mmPerPixel: number;
  readonly center: Vec2;
  readonly rotationDeg: number;
  readonly opacity: number;
}

export interface ReferenceImageCalibration {
  readonly dataUrl: string;
  readonly naturalWidth: number;
  readonly naturalHeight: number;
  readonly viewportWidth: number;
  readonly viewportHeight: number;
  readonly imageZoom: number;
  readonly imagePan: Vec2;
  readonly referenceDiameterMm: number;
  readonly referenceDiameterPx: number;
  readonly imageRotationDeg?: number;
}

export function createPatternReferenceImage(calibration: ReferenceImageCalibration): PatternReferenceImage {
  const containScale = Math.min(
    calibration.viewportWidth / calibration.naturalWidth,
    calibration.viewportHeight / calibration.naturalHeight,
  );
  const screenPixelsPerImagePixel = containScale * calibration.imageZoom;
  const mmPerScreenPixel = calibration.referenceDiameterMm / calibration.referenceDiameterPx;

  return {
    id: crypto.randomUUID(),
    dataUrl: calibration.dataUrl,
    naturalWidth: calibration.naturalWidth,
    naturalHeight: calibration.naturalHeight,
    mmPerPixel: screenPixelsPerImagePixel * mmPerScreenPixel,
    center: {
      x: calibration.imagePan.x * mmPerScreenPixel,
      y: -calibration.imagePan.y * mmPerScreenPixel,
    },
    rotationDeg: calibration.imageRotationDeg ?? 0,
    opacity: 0.38,
  };
}
