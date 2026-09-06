import { distancePointToSegment } from '../geometry/PointInPolygon';
import type { Pattern, Vec2 } from '../patterns/Pattern';

export const PATTERN_HIT_TOLERANCE_MM = 0.15;

export type PatternEndpointHandle = 'start' | 'end';

export interface PatternHit {
  readonly segmentId: string;
  readonly endpoint?: PatternEndpointHandle;
}

export function hitTestPattern(pattern: Pattern | undefined, point: Vec2, toleranceMm = PATTERN_HIT_TOLERANCE_MM): PatternHit | undefined {
  if (!pattern) {
    return undefined;
  }

  for (const segment of pattern.segments) {
    if (Math.hypot(point.u - segment.start.u, point.v - segment.start.v) <= toleranceMm) {
      return { segmentId: segment.id, endpoint: 'start' };
    }
    if (Math.hypot(point.u - segment.end.u, point.v - segment.end.v) <= toleranceMm) {
      return { segmentId: segment.id, endpoint: 'end' };
    }
  }

  let closest: PatternHit | undefined;
  let closestDistance = Infinity;
  for (const segment of pattern.segments) {
    const distance = distancePointToSegment(point, segment.start, segment.end);
    if (distance <= toleranceMm && distance < closestDistance) {
      closest = { segmentId: segment.id };
      closestDistance = distance;
    }
  }

  return closest;
}
