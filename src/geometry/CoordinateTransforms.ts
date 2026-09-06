import type { Vec3 } from './GemGeometry';
import type { FacetFrame } from './FacetFrame';
import { add, dot, scale, subtract } from './vectorMath';

export interface LocalCoordinates {
  readonly u: number;
  readonly v: number;
  readonly n: number;
}

export function localToWorld(frame: FacetFrame, u: number, v: number, offsetNormal = 0): Vec3 {
  return add(
    add(add(frame.origin, scale(frame.uAxis, u)), scale(frame.vAxis, v)),
    scale(frame.normal, offsetNormal),
  );
}

export function worldToLocal(frame: FacetFrame, point: Vec3): LocalCoordinates {
  const delta = subtract(point, frame.origin);
  return {
    u: dot(delta, frame.uAxis),
    v: dot(delta, frame.vAxis),
    n: dot(delta, frame.normal),
  };
}
