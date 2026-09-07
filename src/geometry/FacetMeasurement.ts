import type { Facet } from './Facet';
import type { GemGeometry } from './GemGeometry';
import { createGemGeometryFromIndexedMesh } from './meshBuilder';

export interface MeasurementPoint {
  readonly x: number;
  readonly y: number;
}

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
  let maximum = 0;
  for (let first = 0; first < facet.boundaryVertexIndices.length; first += 1) {
    const a = geometry.vertices[facet.boundaryVertexIndices[first]];
    for (let second = first + 1; second < facet.boundaryVertexIndices.length; second += 1) {
      const b = geometry.vertices[facet.boundaryVertexIndices[second]];
      maximum = Math.max(maximum, Math.hypot(b.x - a.x, b.y - a.y, b.z - a.z));
    }
  }
  return maximum;
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
