import type { Vec3 } from '../../geometry/GemGeometry';
import { add, dot, length, normalize, scale, subtract } from '../../geometry/vectorMath';

export const AIR_IOR = 1;

export function reflectDirection(incident: Vec3, normal: Vec3): Vec3 {
  const i = normalize(incident);
  const n = normalize(normal);
  return normalize(subtract(i, scale(n, 2 * dot(i, n))));
}

export function refractDirection(incident: Vec3, outwardNormal: Vec3, n1: number, n2: number): Vec3 | undefined {
  const i = normalize(incident);
  let n = normalize(outwardNormal);
  let cosI = -Math.max(-1, Math.min(1, dot(i, n)));

  if (cosI < 0) {
    cosI = -cosI;
    n = scale(n, -1);
  }

  const eta = n1 / n2;
  const k = 1 - eta * eta * (1 - cosI * cosI);
  if (k < 0) {
    return undefined;
  }

  return normalize(add(scale(i, eta), scale(n, eta * cosI - Math.sqrt(k))));
}

export function fresnelDielectric(incident: Vec3, outwardNormal: Vec3, n1: number, n2: number): number {
  const i = normalize(incident);
  const n = normalize(outwardNormal);
  const cosI = Math.abs(Math.max(-1, Math.min(1, dot(i, n))));

  const sinT = (n1 / n2) * Math.sqrt(Math.max(0, 1 - cosI * cosI));
  if (sinT >= 1) {
    return 1;
  }

  const cosT = Math.sqrt(Math.max(0, 1 - sinT * sinT));
  const rs = ((n2 * cosI - n1 * cosT) / (n2 * cosI + n1 * cosT)) ** 2;
  const rp = ((n1 * cosI - n2 * cosT) / (n1 * cosI + n2 * cosT)) ** 2;
  return (rs + rp) / 2;
}

export function criticalAngleDeg(nInside: number, nOutside = AIR_IOR): number | undefined {
  if (nInside <= nOutside) {
    return undefined;
  }
  return (Math.asin(nOutside / nInside) * 180) / Math.PI;
}

export function rayOffset(point: Vec3, direction: Vec3, epsilon: number): Vec3 {
  return add(point, scale(normalize(direction), epsilon));
}

export function angleBetween(a: Vec3, b: Vec3) {
  const denominator = length(a) * length(b);
  if (denominator === 0) {
    return 0;
  }
  return Math.acos(Math.max(-1, Math.min(1, dot(a, b) / denominator)));
}
