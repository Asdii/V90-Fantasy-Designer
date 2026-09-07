import {
  createLinePrimitive,
  createPolylinePrimitive,
  type LinePrimitive,
  type PolylinePrimitive,
  type PrimitiveRole,
  type Vec2,
} from '../model/PatternModel';

interface LinearPatternOptions {
  readonly outerRadius: number;
  readonly innerRadius: number;
  readonly rotationDeg: number;
  readonly center?: Vec2;
  readonly role?: PrimitiveRole;
}

export interface GeometricStarOptions extends LinearPatternOptions {
  readonly points: number;
}

export interface RadialBurstOptions extends LinearPatternOptions {
  readonly count: number;
}

export function createGeometricStarPrimitive(options: GeometricStarOptions): PolylinePrimitive {
  const pointCount = Math.max(3, Math.round(options.points));
  const center = options.center ?? { x: 0, y: 0 };
  const outerRadius = Math.max(0, options.outerRadius);
  const innerRadius = Math.min(outerRadius, Math.max(0, options.innerRadius));
  const points = Array.from({ length: pointCount * 2 }, (_, index) => {
    const radius = index % 2 === 0 ? outerRadius : innerRadius;
    return radialPoint(center, radius, options.rotationDeg + (index * 180) / pointCount);
  });
  return createPolylinePrimitive(points, true, options.role ?? 'pattern');
}

export function createRadialBurstPrimitives(options: RadialBurstOptions): LinePrimitive[] {
  const count = Math.max(1, Math.round(options.count));
  const center = options.center ?? { x: 0, y: 0 };
  const outerRadius = Math.max(0, options.outerRadius);
  const innerRadius = Math.min(outerRadius, Math.max(0, options.innerRadius));
  return Array.from({ length: count }, (_, index) => {
    const angle = options.rotationDeg + (index * 360) / count;
    return createLinePrimitive(
      radialPoint(center, innerRadius, angle),
      radialPoint(center, outerRadius, angle),
      options.role ?? 'pattern',
    );
  });
}

function radialPoint(center: Vec2, radius: number, angleDeg: number): Vec2 {
  const radians = (angleDeg * Math.PI) / 180;
  return {
    x: center.x + Math.cos(radians) * radius,
    y: center.y + Math.sin(radians) * radius,
  };
}
