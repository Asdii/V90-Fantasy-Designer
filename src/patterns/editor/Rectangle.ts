import { createPolylinePrimitive, type PolylinePrimitive, type PrimitiveRole, type Vec2 } from '../model/PatternModel';

export function createRectanglePrimitive(
  firstCorner: Vec2,
  oppositeCorner: Vec2,
  role: PrimitiveRole = 'pattern',
): PolylinePrimitive {
  return createPolylinePrimitive(
    [
      firstCorner,
      { x: oppositeCorner.x, y: firstCorner.y },
      oppositeCorner,
      { x: firstCorner.x, y: oppositeCorner.y },
    ],
    true,
    role,
  );
}

export function createCenteredRectanglePrimitive(
  center: Vec2,
  sizePoint: Vec2,
  rotationDeg = 0,
  role: PrimitiveRole = 'pattern',
): PolylinePrimitive {
  const halfWidth = Math.abs(sizePoint.x - center.x);
  const halfHeight = Math.abs(sizePoint.y - center.y);
  const radians = (rotationDeg * Math.PI) / 180;
  const cos = Math.cos(radians);
  const sin = Math.sin(radians);
  const rotate = (x: number, y: number): Vec2 => ({
    x: center.x + x * cos - y * sin,
    y: center.y + x * sin + y * cos,
  });
  return createPolylinePrimitive(
    [
      rotate(-halfWidth, -halfHeight),
      rotate(halfWidth, -halfHeight),
      rotate(halfWidth, halfHeight),
      rotate(-halfWidth, halfHeight),
    ],
    true,
    role,
  );
}
