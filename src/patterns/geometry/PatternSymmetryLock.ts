import type { DesignPattern, PatternPrimitive, Vec2 } from '../model/PatternModel';

export interface PatternSymmetryConstraint {
  readonly rotationOrder: number;
  readonly reflectionAxisDeg?: number;
  readonly tolerance: number;
}

interface Segment2D {
  readonly start: Vec2;
  readonly end: Vec2;
}

const MAX_ROTATION_ORDER = 24;

export function inferPatternSymmetryConstraint(pattern: DesignPattern): PatternSymmetryConstraint | undefined {
  const segments = patternSegments(pattern);
  if (segments.length === 0) {
    return undefined;
  }

  const tolerance = symmetryTolerance(segments);
  let rotationOrder = 1;
  for (let order = MAX_ROTATION_ORDER; order >= 2; order -= 1) {
    if (segmentsEquivalent(segments, transformSegments(segments, (point) => rotatePoint(point, 360 / order)), tolerance)) {
      rotationOrder = order;
      break;
    }
  }

  const reflectionAxisDeg = findReflectionAxis(segments, tolerance);
  if (rotationOrder === 1 && reflectionAxisDeg === undefined) {
    return undefined;
  }

  return { rotationOrder, reflectionAxisDeg, tolerance };
}

export function patternMatchesSymmetryConstraint(
  pattern: DesignPattern,
  constraint: PatternSymmetryConstraint,
): boolean {
  const segments = patternSegments(pattern);
  if (segments.length === 0) {
    return true;
  }

  const tolerance = Math.max(constraint.tolerance, symmetryTolerance(segments));
  if (constraint.rotationOrder > 1) {
    const rotated = transformSegments(segments, (point) => rotatePoint(point, 360 / constraint.rotationOrder));
    if (!segmentsEquivalent(segments, rotated, tolerance)) {
      return false;
    }
  }

  if (constraint.reflectionAxisDeg !== undefined) {
    const reflected = transformSegments(segments, (point) => reflectPoint(point, constraint.reflectionAxisDeg as number));
    if (!segmentsEquivalent(segments, reflected, tolerance)) {
      return false;
    }
  }

  return true;
}

function patternSegments(pattern: DesignPattern): Segment2D[] {
  return pattern.primitives
    .filter((primitive) => primitive.role === 'pattern')
    .flatMap(primitiveSegments);
}

function primitiveSegments(primitive: PatternPrimitive): Segment2D[] {
  if (primitive.type === 'line') {
    return [{ start: primitive.start, end: primitive.end }];
  }
  if (primitive.type !== 'polyline') {
    return [];
  }

  const segments: Segment2D[] = [];
  for (let index = 0; index + 1 < primitive.points.length; index += 1) {
    segments.push({ start: primitive.points[index], end: primitive.points[index + 1] });
  }
  if (primitive.closed && primitive.points.length > 2) {
    segments.push({ start: primitive.points[primitive.points.length - 1], end: primitive.points[0] });
  }
  return segments;
}

function findReflectionAxis(segments: readonly Segment2D[], tolerance: number): number | undefined {
  const candidates = new Set<number>([0, 90]);
  for (const segment of segments) {
    for (const point of [segment.start, segment.end, midpoint(segment)]) {
      if (Math.hypot(point.x, point.y) <= tolerance) {
        continue;
      }
      candidates.add(normalizeAxisAngle((Math.atan2(point.y, point.x) * 180) / Math.PI));
    }
  }

  for (const axisDeg of candidates) {
    const reflected = transformSegments(segments, (point) => reflectPoint(point, axisDeg));
    if (segmentsEquivalent(segments, reflected, tolerance)) {
      return axisDeg;
    }
  }
  return undefined;
}

function transformSegments(segments: readonly Segment2D[], transform: (point: Vec2) => Vec2): Segment2D[] {
  return segments.map((segment) => ({ start: transform(segment.start), end: transform(segment.end) }));
}

function segmentsEquivalent(reference: readonly Segment2D[], candidate: readonly Segment2D[], tolerance: number): boolean {
  if (reference.length !== candidate.length) {
    return false;
  }
  const used = new Set<number>();
  for (const segment of candidate) {
    const match = reference.findIndex((referenceSegment, index) =>
      !used.has(index) && segmentsMatch(referenceSegment, segment, tolerance));
    if (match < 0) {
      return false;
    }
    used.add(match);
  }
  return true;
}

function segmentsMatch(a: Segment2D, b: Segment2D, tolerance: number) {
  return (
    pointsMatch(a.start, b.start, tolerance) && pointsMatch(a.end, b.end, tolerance)
  ) || (
    pointsMatch(a.start, b.end, tolerance) && pointsMatch(a.end, b.start, tolerance)
  );
}

function pointsMatch(a: Vec2, b: Vec2, tolerance: number) {
  return Math.hypot(a.x - b.x, a.y - b.y) <= tolerance;
}

function rotatePoint(point: Vec2, angleDeg: number): Vec2 {
  const radians = (angleDeg * Math.PI) / 180;
  const cos = Math.cos(radians);
  const sin = Math.sin(radians);
  return { x: point.x * cos - point.y * sin, y: point.x * sin + point.y * cos };
}

function reflectPoint(point: Vec2, axisDeg: number): Vec2 {
  const radians = (axisDeg * Math.PI) / 180;
  const axis = { x: Math.cos(radians), y: Math.sin(radians) };
  const projection = point.x * axis.x + point.y * axis.y;
  return {
    x: 2 * projection * axis.x - point.x,
    y: 2 * projection * axis.y - point.y,
  };
}

function midpoint(segment: Segment2D): Vec2 {
  return { x: (segment.start.x + segment.end.x) / 2, y: (segment.start.y + segment.end.y) / 2 };
}

function symmetryTolerance(segments: readonly Segment2D[]) {
  const extent = Math.max(1, ...segments.flatMap((segment) => [
    Math.abs(segment.start.x), Math.abs(segment.start.y), Math.abs(segment.end.x), Math.abs(segment.end.y),
  ]));
  return extent * 1e-5;
}

function normalizeAxisAngle(angleDeg: number) {
  const normalized = ((angleDeg % 180) + 180) % 180;
  return Math.abs(normalized - 180) < 1e-10 ? 0 : normalized;
}
