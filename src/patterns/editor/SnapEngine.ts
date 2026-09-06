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
  return primitives.flatMap((primitive) => (primitive.type === 'circle' || primitive.type === 'arc' ? [primitive.center] : []));
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
