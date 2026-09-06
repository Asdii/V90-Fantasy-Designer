import type { CutPath, DesignPattern, PatternPrimitive, Vec2 } from '../model/PatternModel';
import { calculateDesignPatternBounds } from './bounds';

export function patternToCutPaths(pattern: DesignPattern, curveSegments = 64): CutPath[] {
  return pattern.primitives
    .filter((primitive) => primitive.role === 'pattern')
    .flatMap((primitive) => primitiveToPath(primitive, curveSegments));
}

export function normalizePattern(pattern: DesignPattern): DesignPattern {
  const bounds = calculateDesignPatternBounds(pattern);
  const size = Math.max(bounds.width, bounds.height);
  if (size <= 0) {
    return pattern;
  }

  const normalizePoint = (point: Vec2): Vec2 => ({
    x: (point.x / size) * 2,
    y: (point.y / size) * 2,
  });

  return {
    ...pattern,
    id: `${pattern.id}-normalized`,
    primitives: pattern.primitives.map((primitive) => normalizePrimitive(primitive, normalizePoint, size)),
  };
}

function primitiveToPath(primitive: PatternPrimitive, curveSegments: number): CutPath[] {
  if (primitive.type === 'line') {
    return [{ points: [primitive.start, primitive.end], closed: false }];
  }
  if (primitive.type === 'polyline') {
    return [{ points: primitive.points, closed: primitive.closed }];
  }
  if (primitive.type === 'circle') {
    return [{ points: circlePoints(primitive.center, primitive.radius, curveSegments, 0, 360), closed: true }];
  }
  return [
    {
      points: circlePoints(primitive.center, primitive.radius, curveSegments, primitive.startAngleDeg, primitive.endAngleDeg),
      closed: false,
    },
  ];
}

function normalizePrimitive(
  primitive: PatternPrimitive,
  normalizePoint: (point: Vec2) => Vec2,
  originalSize: number,
): PatternPrimitive {
  if (primitive.type === 'line') {
    return { ...primitive, start: normalizePoint(primitive.start), end: normalizePoint(primitive.end) };
  }
  if (primitive.type === 'polyline') {
    return { ...primitive, points: primitive.points.map(normalizePoint) };
  }
  if (primitive.type === 'circle') {
    return { ...primitive, center: normalizePoint(primitive.center), radius: (primitive.radius / originalSize) * 2 };
  }
  return { ...primitive, center: normalizePoint(primitive.center), radius: (primitive.radius / originalSize) * 2 };
}

function circlePoints(center: Vec2, radius: number, curveSegments: number, startAngleDeg: number, endAngleDeg: number): Vec2[] {
  const count = Math.max(4, Math.round(curveSegments));
  const delta = endAngleDeg - startAngleDeg;
  return Array.from({ length: count + 1 }, (_, index) => {
    const angle = startAngleDeg + (delta * index) / count;
    const radians = (angle * Math.PI) / 180;
    return { x: center.x + Math.cos(radians) * radius, y: center.y + Math.sin(radians) * radius };
  });
}
