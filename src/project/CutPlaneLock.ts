import type { Vec3 } from '../geometry/GemGeometry';
import { dot, normalize } from '../geometry/vectorMath';

export const CUT_PLANE_ANGULAR_TOLERANCE_DEGREES = 0.1;

export function areCutPlaneNormalsCompatible(
  referenceNormal: Vec3,
  candidateNormal: Vec3,
  toleranceDegrees = CUT_PLANE_ANGULAR_TOLERANCE_DEGREES,
) {
  const threshold = Math.cos((toleranceDegrees * Math.PI) / 180);
  return dot(normalize(referenceNormal), normalize(candidateNormal)) >= threshold;
}
