import type { LineSegment2D, Pattern, PatternTransform, Vec2 } from './Pattern';
import { createSegment, identityPatternTransform } from './Pattern';

export interface PatternBounds {
  readonly minU: number;
  readonly maxU: number;
  readonly minV: number;
  readonly maxV: number;
  readonly width: number;
  readonly height: number;
}

export function segmentLength(segment: Pick<LineSegment2D, 'start' | 'end'>): number {
  return Math.hypot(segment.end.u - segment.start.u, segment.end.v - segment.start.v);
}

export function segmentAngleDegrees(segment: Pick<LineSegment2D, 'start' | 'end'>): number {
  return (Math.atan2(segment.end.v - segment.start.v, segment.end.u - segment.start.u) * 180) / Math.PI;
}

export function transformPoint(point: Vec2, transform: PatternTransform): Vec2 {
  const radians = (transform.rotationDeg * Math.PI) / 180;
  const cos = Math.cos(radians);
  const sin = Math.sin(radians);
  const scaledU = point.u * transform.scale;
  const scaledV = point.v * transform.scale;
  return {
    u: scaledU * cos - scaledV * sin + transform.offsetU,
    v: scaledU * sin + scaledV * cos + transform.offsetV,
  };
}

export function inverseTransformPoint(point: Vec2, transform: PatternTransform): Vec2 {
  const scale = transform.scale === 0 ? 1 : transform.scale;
  const translatedU = point.u - transform.offsetU;
  const translatedV = point.v - transform.offsetV;
  const radians = (-transform.rotationDeg * Math.PI) / 180;
  const cos = Math.cos(radians);
  const sin = Math.sin(radians);
  return {
    u: (translatedU * cos - translatedV * sin) / scale,
    v: (translatedU * sin + translatedV * cos) / scale,
  };
}

export function transformSegment(segment: LineSegment2D, transform: PatternTransform): LineSegment2D {
  return {
    ...segment,
    start: transformPoint(segment.start, transform),
    end: transformPoint(segment.end, transform),
  };
}

export function getPatternTransform(pattern?: Pattern): PatternTransform {
  return pattern?.transform ?? identityPatternTransform;
}

export function createRectangleSegments(first: Vec2, second: Vec2): LineSegment2D[] {
  const a = { u: first.u, v: first.v };
  const b = { u: second.u, v: first.v };
  const c = { u: second.u, v: second.v };
  const d = { u: first.u, v: second.v };
  return [createSegment(a, b), createSegment(b, c), createSegment(c, d), createSegment(d, a)];
}

export function createPolylineSegments(points: readonly Vec2[], closed = false): LineSegment2D[] {
  const segments: LineSegment2D[] = [];
  for (let index = 0; index + 1 < points.length; index += 1) {
    segments.push(createSegment(points[index], points[index + 1]));
  }

  if (closed && points.length > 2) {
    segments.push(createSegment(points[points.length - 1], points[0]));
  }

  return segments;
}

export function createCircleSegments(center: Vec2, edgePoint: Vec2, segmentCount = 48): LineSegment2D[] {
  const radius = Math.hypot(edgePoint.u - center.u, edgePoint.v - center.v);
  if (radius === 0) {
    return [];
  }

  const points = Array.from({ length: segmentCount }, (_, index) => {
    const angle = (index / segmentCount) * Math.PI * 2;
    return {
      u: center.u + Math.cos(angle) * radius,
      v: center.v + Math.sin(angle) * radius,
    };
  });

  return createPolylineSegments(points, true);
}

export function calculatePatternBounds(pattern?: Pattern): PatternBounds {
  const transform = getPatternTransform(pattern);
  const points = pattern?.segments.flatMap((segment) => [transformPoint(segment.start, transform), transformPoint(segment.end, transform)]) ?? [];
  if (points.length === 0) {
    return { minU: 0, maxU: 0, minV: 0, maxV: 0, width: 0, height: 0 };
  }

  let minU = points[0].u;
  let maxU = points[0].u;
  let minV = points[0].v;
  let maxV = points[0].v;

  for (const point of points) {
    minU = Math.min(minU, point.u);
    maxU = Math.max(maxU, point.u);
    minV = Math.min(minV, point.v);
    maxV = Math.max(maxV, point.v);
  }

  return { minU, maxU, minV, maxV, width: maxU - minU, height: maxV - minV };
}

export function replaceSegment(pattern: Pattern, segment: LineSegment2D): Pattern {
  return {
    ...pattern,
    transform: getPatternTransform(pattern),
    segments: pattern.segments.map((item) => (item.id === segment.id ? segment : item)),
  };
}

export function removeSegment(pattern: Pattern, segmentId: string): Pattern {
  return {
    ...pattern,
    transform: getPatternTransform(pattern),
    segments: pattern.segments.filter((segment) => segment.id !== segmentId),
  };
}

export function mirrorSegments(segments: readonly LineSegment2D[], axis: 'u' | 'v'): LineSegment2D[] {
  return segments.map((segment) =>
    createSegment(mirrorPoint(segment.start, axis), mirrorPoint(segment.end, axis)),
  );
}

export function rotateSegments(
  segments: readonly LineSegment2D[],
  rotationDeg: number,
  center: Vec2 = { u: 0, v: 0 },
): LineSegment2D[] {
  return segments.map((segment) =>
    createSegment(rotatePoint(segment.start, rotationDeg, center), rotatePoint(segment.end, rotationDeg, center)),
  );
}

export function circularArraySegments(
  segments: readonly LineSegment2D[],
  copies: number,
  center: Vec2,
  totalAngleDeg: number,
  startAngleDeg: number,
): LineSegment2D[] {
  if (copies <= 0) {
    return [];
  }

  const step = copies === 1 ? 0 : totalAngleDeg / copies;
  return Array.from({ length: copies }, (_, index) =>
    rotateSegments(segments, startAngleDeg + step * index, center),
  ).flat();
}

function mirrorPoint(point: Vec2, axis: 'u' | 'v'): Vec2 {
  return axis === 'u' ? { u: point.u, v: -point.v } : { u: -point.u, v: point.v };
}

function rotatePoint(point: Vec2, rotationDeg: number, center: Vec2): Vec2 {
  const radians = (rotationDeg * Math.PI) / 180;
  const cos = Math.cos(radians);
  const sin = Math.sin(radians);
  const du = point.u - center.u;
  const dv = point.v - center.v;
  return {
    u: center.u + du * cos - dv * sin,
    v: center.v + du * sin + dv * cos,
  };
}
