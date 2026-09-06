import { isPointInsideFacetLocal } from '../geometry/PointInPolygon';
import type { LineSegment2D, Vec2 } from './Pattern';

export interface ClippedSegmentParts {
  readonly inside: readonly LineSegment2D[];
  readonly outside: readonly LineSegment2D[];
}

export function clipSegmentToFacetPolygon(
  segment: LineSegment2D,
  polygon: readonly Vec2[],
): ClippedSegmentParts {
  if (polygon.length < 3) {
    return { inside: [], outside: [segment] };
  }

  const tValues = new Set<number>([0, 1]);
  for (let index = 0; index < polygon.length; index += 1) {
    const t = segmentIntersectionT(segment.start, segment.end, polygon[index], polygon[(index + 1) % polygon.length]);
    if (t !== undefined && t >= 0 && t <= 1) {
      tValues.add(clamp01(t));
    }
  }

  const sorted = Array.from(tValues).sort((a, b) => a - b);
  const inside: LineSegment2D[] = [];
  const outside: LineSegment2D[] = [];

  for (let index = 0; index + 1 < sorted.length; index += 1) {
    const t0 = sorted[index];
    const t1 = sorted[index + 1];
    if (Math.abs(t1 - t0) < 1e-10) {
      continue;
    }

    const start = lerpPoint(segment.start, segment.end, t0);
    const end = lerpPoint(segment.start, segment.end, t1);
    const midpoint = lerpPoint(segment.start, segment.end, (t0 + t1) / 2);
    const part = { ...segment, id: `${segment.id}-${index}`, start, end };
    if (isPointInsideFacetLocal(midpoint, polygon)) {
      inside.push(part);
    } else {
      outside.push(part);
    }
  }

  return { inside, outside };
}

function segmentIntersectionT(p: Vec2, p2: Vec2, q: Vec2, q2: Vec2): number | undefined {
  const r = { u: p2.u - p.u, v: p2.v - p.v };
  const s = { u: q2.u - q.u, v: q2.v - q.v };
  const denominator = cross2(r, s);

  if (Math.abs(denominator) < 1e-12) {
    return undefined;
  }

  const qp = { u: q.u - p.u, v: q.v - p.v };
  const t = cross2(qp, s) / denominator;
  const u = cross2(qp, r) / denominator;
  return t >= -1e-10 && t <= 1 + 1e-10 && u >= -1e-10 && u <= 1 + 1e-10 ? t : undefined;
}

function cross2(a: Vec2, b: Vec2) {
  return a.u * b.v - a.v * b.u;
}

function lerpPoint(a: Vec2, b: Vec2, t: number): Vec2 {
  return { u: a.u + (b.u - a.u) * t, v: a.v + (b.v - a.v) * t };
}

function clamp01(value: number) {
  return Math.max(0, Math.min(1, value));
}
