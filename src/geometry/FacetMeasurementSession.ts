import type { MeasurementPoint } from './FacetMeasurement';

export interface FacetMeasurementSession {
  readonly imageUrl?: string;
  readonly imageSize?: { readonly width: number; readonly height: number };
  readonly imageZoom: number;
  readonly imagePan: MeasurementPoint;
  readonly imageRotationDeg: number;
  readonly referenceDiameterMm: number;
  readonly referenceCenter?: MeasurementPoint;
  readonly points: readonly MeasurementPoint[];
}

export function createDefaultFacetMeasurementSession(): FacetMeasurementSession {
  return {
    imageZoom: 1,
    imagePan: { x: 0, y: 0 },
    imageRotationDeg: 0,
    referenceDiameterMm: 10,
    points: [],
  };
}

export function constrainMeasurementPoint(
  start: MeasurementPoint,
  candidate: MeasurementPoint,
): MeasurementPoint {
  return Math.abs(candidate.x - start.x) >= Math.abs(candidate.y - start.y)
    ? { x: candidate.x, y: start.y }
    : { x: start.x, y: candidate.y };
}
