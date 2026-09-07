import type { DesignPattern, LinePrimitive, PatternPrimitive, Vec2 } from '../model/PatternModel';
import { findLineIntersections } from '../geometry/intersections';

export interface SnapOptions {
  readonly enabled: boolean;
  readonly gridSpacing: number;
  readonly snapDistanceWorld: number;
}

export interface SnapResult {
  readonly point: Vec2;
  readonly source: 'grid' | 'endpoint' | 'intersection' | 'center' | 'raw';
}

export interface RadialSnapOptions extends SnapOptions {
  readonly center: Vec2;
  readonly angleStepDeg?: number;
}

export function snapEditorPoint(rawPoint: Vec2, pattern: DesignPattern, options: SnapOptions): SnapResult {
  if (!options.enabled) {
    return { point: rawPoint, source: 'raw' };
  }

  const candidates = [
    ...endpointCandidates(pattern.primitives).map((point) => ({ point, source: 'endpoint' as const })),
    ...intersectionCandidates(pattern.primitives).map((point) => ({ point, source: 'intersection' as const })),
    ...centerCandidates(pattern.primitives).map((point) => ({ point, source: 'center' as const })),
  ];

  let nearest: SnapResult | undefined;
  let nearestDistance = Infinity;
  for (const candidate of candidates) {
    const distance = distance2D(rawPoint, candidate.point);
    if (distance <= options.snapDistanceWorld && distance < nearestDistance) {
      nearest = candidate;
      nearestDistance = distance;
    }
  }

  if (nearest) {
    return nearest;
  }

  if (options.gridSpacing > 0) {
    return {
      point: {
        x: Math.round(rawPoint.x / options.gridSpacing) * options.gridSpacing,
        y: Math.round(rawPoint.y / options.gridSpacing) * options.gridSpacing,
      },
      source: 'grid',
    };
  }

  return { point: rawPoint, source: 'raw' };
}

export function snapRegularShapePoint(rawPoint: Vec2, pattern: DesignPattern, options: RadialSnapOptions): Vec2 {
  const dx = rawPoint.x - options.center.x;
  const dy = rawPoint.y - options.center.y;
  let radius = Math.hypot(dx, dy);
  let angle = Math.atan2(dy, dx);

  if (options.angleStepDeg && options.angleStepDeg > 0) {
    const step = (options.angleStepDeg * Math.PI) / 180;
    angle = Math.round(angle / step) * step;
  }

  if (options.enabled) {
    const matchingRadius = regularShapeRadii(pattern.primitives, options.center)
      .map((candidate) => ({ candidate, distance: Math.abs(candidate - radius) }))
      .filter(({ distance }) => distance <= options.snapDistanceWorld)
      .sort((a, b) => a.distance - b.distance)[0]?.candidate;

    if (matchingRadius !== undefined) {
      radius = matchingRadius;
    } else if (options.gridSpacing > 0) {
      radius = Math.round(radius / options.gridSpacing) * options.gridSpacing;
    }
  }

  return {
    x: options.center.x + Math.cos(angle) * radius,
    y: options.center.y + Math.sin(angle) * radius,
  };
}

function endpointCandidates(primitives: readonly PatternPrimitive[]): Vec2[] {
  return primitives.flatMap((primitive) => {
    if (primitive.type === 'line') {
      return [primitive.start, primitive.end];
    }
    if (primitive.type === 'polyline') {
      return [...primitive.points];
    }
    if (primitive.type === 'arc') {
      return [
        pointOnCircle(primitive.center, primitive.radius, primitive.startAngleDeg),
        pointOnCircle(primitive.center, primitive.radius, primitive.endAngleDeg),
      ];
    }
    return [];
  });
}

function centerCandidates(primitives: readonly PatternPrimitive[]): Vec2[] {
  return primitives.flatMap((primitive) => {
    if (primitive.type === 'circle' || primitive.type === 'arc') {
      return [primitive.center];
    }
    if (primitive.type === 'polyline' && primitive.closed && primitive.points.length > 2) {
      return [polygonCenter(primitive.points)];
    }
    return [];
  });
}

function regularShapeRadii(primitives: readonly PatternPrimitive[], center: Vec2): number[] {
  return primitives.flatMap((primitive) => {
    if (primitive.type === 'circle' && distance2D(primitive.center, center) <= 1e-6) {
      return [primitive.radius];
    }
    if (primitive.type !== 'polyline' || !primitive.closed || primitive.points.length < 3) {
      return [];
    }
    const primitiveCenter = polygonCenter(primitive.points);
    if (distance2D(primitiveCenter, center) > 1e-6) {
      return [];
    }
    const radii = primitive.points.map((point) => distance2D(point, primitiveCenter));
    const mean = radii.reduce((sum, value) => sum + value, 0) / radii.length;
    const tolerance = Math.max(mean * 1e-6, 1e-9);
    return radii.every((value) => Math.abs(value - mean) <= tolerance) ? [mean] : [];
  });
}

function polygonCenter(points: readonly Vec2[]): Vec2 {
  return points.reduce(
    (center, point) => ({ x: center.x + point.x / points.length, y: center.y + point.y / points.length }),
    { x: 0, y: 0 },
  );
}

function intersectionCandidates(primitives: readonly PatternPrimitive[]): Vec2[] {
  const lines: LinePrimitive[] = primitives.flatMap((primitive) => {
    if (primitive.type === 'line') {
      return [primitive];
    }
    if (primitive.type === 'polyline') {
      const segments: LinePrimitive[] = [];
      for (let index = 0; index + 1 < primitive.points.length; index += 1) {
        segments.push({
          id: `${primitive.id}-${index}`,
          type: 'line',
          role: primitive.role,
          start: primitive.points[index],
          end: primitive.points[index + 1],
        });
      }
      if (primitive.closed && primitive.points.length > 2) {
        segments.push({
          id: `${primitive.id}-closed`,
          type: 'line',
          role: primitive.role,
          start: primitive.points[primitive.points.length - 1],
          end: primitive.points[0],
        });
      }
      return segments;
    }
    return [];
  });

  return findLineIntersections(lines);
}

function pointOnCircle(center: Vec2, radius: number, angleDeg: number): Vec2 {
  const radians = (angleDeg * Math.PI) / 180;
  return { x: center.x + Math.cos(radians) * radius, y: center.y + Math.sin(radians) * radius };
}

function distance2D(a: Vec2, b: Vec2) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}
