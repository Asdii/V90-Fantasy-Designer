import type { DesignPattern, PatternPrimitive, Vec2 } from '../model/PatternModel';

export interface PatternBounds {
  readonly minX: number;
  readonly maxX: number;
  readonly minY: number;
  readonly maxY: number;
  readonly width: number;
  readonly height: number;
  readonly center: Vec2;
}

export function calculatePrimitiveBounds(primitive: PatternPrimitive): PatternBounds {
  const points = primitiveSamplePoints(primitive);
  return calculatePointBounds(points);
}

export function calculateDesignPatternBounds(pattern: DesignPattern): PatternBounds {
  return calculatePointBounds(pattern.primitives.flatMap((primitive) => primitiveSamplePoints(primitive)));
}

export function calculatePointBounds(points: readonly Vec2[]): PatternBounds {
  if (points.length === 0) {
    return { minX: 0, maxX: 0, minY: 0, maxY: 0, width: 0, height: 0, center: { x: 0, y: 0 } };
  }

  let minX = points[0].x;
  let maxX = points[0].x;
  let minY = points[0].y;
  let maxY = points[0].y;
  for (const point of points) {
    minX = Math.min(minX, point.x);
    maxX = Math.max(maxX, point.x);
    minY = Math.min(minY, point.y);
    maxY = Math.max(maxY, point.y);
  }

  return {
    minX,
    maxX,
    minY,
    maxY,
    width: maxX - minX,
    height: maxY - minY,
    center: { x: (minX + maxX) / 2, y: (minY + maxY) / 2 },
  };
}

function primitiveSamplePoints(primitive: PatternPrimitive): Vec2[] {
  if (primitive.type === 'line') {
    return [primitive.start, primitive.end];
  }
  if (primitive.type === 'polyline') {
    return [...primitive.points];
  }
  if (primitive.type === 'circle') {
    return [
      { x: primitive.center.x - primitive.radius, y: primitive.center.y - primitive.radius },
      { x: primitive.center.x + primitive.radius, y: primitive.center.y + primitive.radius },
    ];
  }

  return [
    pointOnArc(primitive.center, primitive.radius, primitive.startAngleDeg),
    pointOnArc(primitive.center, primitive.radius, primitive.endAngleDeg),
    { x: primitive.center.x - primitive.radius, y: primitive.center.y - primitive.radius },
    { x: primitive.center.x + primitive.radius, y: primitive.center.y + primitive.radius },
  ];
}

function pointOnArc(center: Vec2, radius: number, angleDeg: number): Vec2 {
  const radians = (angleDeg * Math.PI) / 180;
  return { x: center.x + Math.cos(radians) * radius, y: center.y + Math.sin(radians) * radius };
}
