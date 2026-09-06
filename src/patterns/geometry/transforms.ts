import type { PatternPrimitive, Vec2 } from '../model/PatternModel';

export interface PrimitiveTransform {
  readonly translateX: number;
  readonly translateY: number;
  readonly rotationDeg: number;
  readonly scale: number;
  readonly center: Vec2;
}

export function transformPoint2D(point: Vec2, transform: PrimitiveTransform): Vec2 {
  const scaled = {
    x: (point.x - transform.center.x) * transform.scale,
    y: (point.y - transform.center.y) * transform.scale,
  };
  const radians = (transform.rotationDeg * Math.PI) / 180;
  const cos = Math.cos(radians);
  const sin = Math.sin(radians);
  return {
    x: transform.center.x + scaled.x * cos - scaled.y * sin + transform.translateX,
    y: transform.center.y + scaled.x * sin + scaled.y * cos + transform.translateY,
  };
}

export function transformPrimitive(primitive: PatternPrimitive, transform: PrimitiveTransform): PatternPrimitive {
  if (primitive.type === 'line') {
    return {
      ...primitive,
      id: crypto.randomUUID(),
      start: transformPoint2D(primitive.start, transform),
      end: transformPoint2D(primitive.end, transform),
    };
  }
  if (primitive.type === 'polyline') {
    return {
      ...primitive,
      id: crypto.randomUUID(),
      points: primitive.points.map((point) => transformPoint2D(point, transform)),
    };
  }
  if (primitive.type === 'circle') {
    return {
      ...primitive,
      id: crypto.randomUUID(),
      center: transformPoint2D(primitive.center, transform),
      radius: primitive.radius * Math.abs(transform.scale),
    };
  }

  return {
    ...primitive,
    id: crypto.randomUUID(),
    center: transformPoint2D(primitive.center, transform),
    radius: primitive.radius * Math.abs(transform.scale),
    startAngleDeg: primitive.startAngleDeg + transform.rotationDeg,
    endAngleDeg: primitive.endAngleDeg + transform.rotationDeg,
  };
}

export function mirrorPrimitive(primitive: PatternPrimitive, axis: 'x' | 'y'): PatternPrimitive {
  const mirrorPoint = (point: Vec2): Vec2 => (axis === 'x' ? { x: point.x, y: -point.y } : { x: -point.x, y: point.y });
  if (primitive.type === 'line') {
    return { ...primitive, id: crypto.randomUUID(), start: mirrorPoint(primitive.start), end: mirrorPoint(primitive.end) };
  }
  if (primitive.type === 'polyline') {
    return { ...primitive, id: crypto.randomUUID(), points: primitive.points.map(mirrorPoint) };
  }
  if (primitive.type === 'circle') {
    return { ...primitive, id: crypto.randomUUID(), center: mirrorPoint(primitive.center) };
  }
  return {
    ...primitive,
    id: crypto.randomUUID(),
    center: mirrorPoint(primitive.center),
    startAngleDeg: mirrorAngle(primitive.startAngleDeg, axis),
    endAngleDeg: mirrorAngle(primitive.endAngleDeg, axis),
  };
}

export function radialDuplicatePrimitives(
  primitives: readonly PatternPrimitive[],
  copies: number,
  center: Vec2,
  totalAngleDeg: number,
): PatternPrimitive[] {
  if (copies <= 0) {
    return [];
  }

  const step = copies === 1 ? 0 : totalAngleDeg / copies;
  return Array.from({ length: copies }, (_, index) =>
    primitives.map((primitive) =>
      transformPrimitive(primitive, {
        translateX: 0,
        translateY: 0,
        rotationDeg: step * index,
        scale: 1,
        center,
      }),
    ),
  ).flat();
}

function mirrorAngle(angleDeg: number, axis: 'x' | 'y') {
  return axis === 'x' ? -angleDeg : 180 - angleDeg;
}
