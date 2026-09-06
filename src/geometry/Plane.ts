import type { Vec3 } from './GemGeometry';
import { dot, scale, subtract } from './vectorMath';

// Plane convention: normal dot point + constant = 0.
export interface Plane {
  readonly normal: Vec3;
  readonly constant: number;
}

export function createPlaneFromPointNormal(point: Vec3, normal: Vec3): Plane {
  return {
    normal,
    constant: -dot(normal, point),
  };
}

export function distancePointToPlane(point: Vec3, plane: Plane): number {
  return dot(plane.normal, point) + plane.constant;
}

export function projectPointOntoPlane(point: Vec3, plane: Plane): Vec3 {
  return subtract(point, scale(plane.normal, distancePointToPlane(point, plane)));
}
