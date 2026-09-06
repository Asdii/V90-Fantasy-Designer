import type { Vec2 } from '../patterns/Pattern';

export const POINT_ON_BOUNDARY_EPSILON_MM = 1e-6;

export function isPointInsideFacetLocal(
  point: Vec2,
  polygon: readonly Vec2[],
  boundaryEpsilonMm = POINT_ON_BOUNDARY_EPSILON_MM,
): boolean {
  if (polygon.length < 3) {
    return false;
  }

  for (let index = 0; index < polygon.length; index += 1) {
    const a = polygon[index];
    const b = polygon[(index + 1) % polygon.length];
    if (distancePointToSegment(point, a, b) <= boundaryEpsilonMm) {
      return true;
    }
  }

  let inside = false;
  for (let index = 0, previousIndex = polygon.length - 1; index < polygon.length; previousIndex = index, index += 1) {
    const a = polygon[index];
    const b = polygon[previousIndex];
    const intersects =
      a.v > point.v !== b.v > point.v &&
      point.u < ((b.u - a.u) * (point.v - a.v)) / (b.v - a.v) + a.u;
    if (intersects) {
      inside = !inside;
    }
  }

  return inside;
}

export function distancePointToSegment(point: Vec2, start: Vec2, end: Vec2): number {
  const du = end.u - start.u;
  const dv = end.v - start.v;
  const lengthSquared = du * du + dv * dv;

  if (lengthSquared === 0) {
    return Math.hypot(point.u - start.u, point.v - start.v);
  }

  const t = Math.max(0, Math.min(1, ((point.u - start.u) * du + (point.v - start.v) * dv) / lengthSquared));
  return Math.hypot(point.u - (start.u + t * du), point.v - (start.v + t * dv));
}
