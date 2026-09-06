import { createPolylinePrimitive, type PolylinePrimitive, type PrimitiveRole, type Vec2 } from '../model/PatternModel';

export interface RegularPolygonOptions {
  readonly sides: number;
  readonly radius: number;
  readonly rotationDeg: number;
  readonly center?: Vec2;
  readonly role?: PrimitiveRole;
}

export function createRegularPolygonPrimitive(options: RegularPolygonOptions): PolylinePrimitive {
  const sides = Math.max(3, Math.round(options.sides));
  const center = options.center ?? { x: 0, y: 0 };
  const points = Array.from({ length: sides }, (_, index) => {
    const angle = options.rotationDeg + (index / sides) * 360;
    const radians = (angle * Math.PI) / 180;
    return {
      x: center.x + Math.cos(radians) * options.radius,
      y: center.y + Math.sin(radians) * options.radius,
    };
  });
  return createPolylinePrimitive(points, true, options.role ?? 'pattern');
}
