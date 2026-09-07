import type { Facet } from './Facet';
import type { GemGeometry } from './GemGeometry';
import { createGemGeometryFromIndexedMesh } from './meshBuilder';

export interface MeasurementPoint {
  readonly x: number;
  readonly y: number;
}

export interface MeasurementSpan {
  readonly start: MeasurementPoint;
  readonly end: MeasurementPoint;
  readonly lengthMm: number;
}

export const MEASUREMENT_PIXELS_PER_MM = 18;

export function calculateMeasuredLengthMm(
  start: MeasurementPoint,
  end: MeasurementPoint,
  referenceDiameterMm: number,
  referenceDiameterPx: number,
): number {
  assertPositiveFinite(referenceDiameterMm, 'Reference diameter');
  assertPositiveFinite(referenceDiameterPx, 'Reference circle size');
  return Math.hypot(end.x - start.x, end.y - start.y) * (referenceDiameterMm / referenceDiameterPx);
}

export function calculateFacetBoundarySpanMm(geometry: GemGeometry, facet: Facet): number {
  const points = facet.boundaryVertexIndices.map((index) => geometry.vertices[index]);
  let maximum = 0;
  for (let first = 0; first < points.length; first += 1) {
    for (let second = first + 1; second < points.length; second += 1) {
      const a = points[first];
      const b = points[second];
      maximum = Math.max(maximum, Math.hypot(b.x - a.x, b.y - a.y, b.z - a.z));
    }
  }
  return maximum;
}

/** Returns the largest point-to-point span of a planar facet boundary. */
export function calculateMaximumMeasurementSpan(points: readonly MeasurementPoint[]): MeasurementSpan {
  if (points.length < 2) {
    throw new Error('A facet boundary needs at least two points to measure its maximum span.');
  }

  let start = points[0];
  let end = points[1];
  let lengthMm = Math.hypot(end.x - start.x, end.y - start.y);
  for (let first = 0; first < points.length; first += 1) {
    for (let second = first + 1; second < points.length; second += 1) {
      const candidate = Math.hypot(points[second].x - points[first].x, points[second].y - points[first].y);
      if (candidate > lengthMm) {
        start = points[first];
        end = points[second];
        lengthMm = candidate;
      }
    }
  }
  return { start, end, lengthMm };
}

export function calculateMeasurementScaleFactor(measuredLengthMm: number, modelLengthMm: number): number {
  assertPositiveFinite(measuredLengthMm, 'Measured facet length');
  assertPositiveFinite(modelLengthMm, 'Model facet length');
  return measuredLengthMm / modelLengthMm;
}

export function scaleGemGeometry(
  geometry: GemGeometry,
  factor: number,
  anchor = geometry.boundingBox.center,
): GemGeometry {
  assertPositiveFinite(factor, 'Geometry scale');
  return createGemGeometryFromIndexedMesh(
    geometry.vertices.map((vertex) => ({
      x: anchor.x + (vertex.x - anchor.x) * factor,
      y: anchor.y + (vertex.y - anchor.y) * factor,
      z: anchor.z + (vertex.z - anchor.z) * factor,
    })),
    geometry.triangles.map(({ a, b, c }) => ({ a, b, c })),
  );
}

function assertPositiveFinite(value: number, label: string) {
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${label} must be a positive finite number.`);
  }
}
