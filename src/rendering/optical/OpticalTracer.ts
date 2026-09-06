import type { GemGeometry, Vec3 } from '../../geometry/GemGeometry';
import { add, dot, normalize, scale } from '../../geometry/vectorMath';
import type { GemMaterial } from '../../materials/GemMaterial';
import { AIR_IOR, fresnelDielectric, reflectDirection, refractDirection, rayOffset } from './OpticalMath';
import { OpticalBVH, type OpticalRay } from './OpticalBVH';

export interface OpticalTraceOptions {
  readonly maxBounces: number;
  readonly rayEpsilonMm: number;
}

export interface OpticalTraceResult {
  readonly color: Vec3;
  readonly bounces: number;
  readonly exited: boolean;
  readonly totalInternalReflections: number;
}

export interface OpticalEnvironment {
  readonly sample: (direction: Vec3) => Vec3;
}

export const defaultOpticalTraceOptions: OpticalTraceOptions = {
  maxBounces: 12,
  rayEpsilonMm: 1e-5,
};

export class OpticalTracer {
  private readonly bvh: OpticalBVH;

  constructor(private readonly geometry: Pick<GemGeometry, 'vertices' | 'triangles'>) {
    this.bvh = new OpticalBVH(geometry);
  }

  trace(ray: OpticalRay, material: Pick<GemMaterial, 'refractiveIndex' | 'color'>, environment: OpticalEnvironment, options = defaultOpticalTraceOptions): OpticalTraceResult {
    let currentRay = { origin: ray.origin, direction: normalize(ray.direction) };
    let insideGem = false;
    let throughput = { x: 1, y: 1, z: 1 };
    let accumulated = { x: 0, y: 0, z: 0 };
    let totalInternalReflections = 0;
    let bounces = 0;

    for (; bounces < options.maxBounces; bounces += 1) {
      const hit = this.bvh.intersect(currentRay, options.rayEpsilonMm);
      if (!hit) {
        accumulated = add(accumulated, multiply(throughput, environment.sample(currentRay.direction)));
        return { color: accumulated, bounces, exited: true, totalInternalReflections };
      }

      const entering = dot(currentRay.direction, hit.normal) < 0;
      const n1 = insideGem ? material.refractiveIndex : AIR_IOR;
      const n2 = insideGem ? AIR_IOR : material.refractiveIndex;
      const fresnel = fresnelDielectric(currentRay.direction, hit.normal, n1, n2);
      const reflected = reflectDirection(currentRay.direction, entering ? hit.normal : scale(hit.normal, -1));
      const refracted = refractDirection(currentRay.direction, hit.normal, n1, n2);

      if (!refracted) {
        totalInternalReflections += 1;
        currentRay = { origin: rayOffset(hit.point, reflected, options.rayEpsilonMm), direction: reflected };
        continue;
      }

      // Deterministic preview path: follow the dominant Fresnel branch and keep the other branch as environment energy.
      if (fresnel > 0.75) {
        currentRay = { origin: rayOffset(hit.point, reflected, options.rayEpsilonMm), direction: reflected };
      } else {
        throughput = multiply(throughput, materialTint(material.color));
        insideGem = !insideGem;
        currentRay = { origin: rayOffset(hit.point, refracted, options.rayEpsilonMm), direction: refracted };
      }
    }

    return { color: accumulated, bounces, exited: false, totalInternalReflections };
  }
}

export function createStudioOpticalEnvironment(kind: 'gemStudio' | 'white' | 'dark' | 'contrast' = 'gemStudio'): OpticalEnvironment {
  return {
    sample(direction: Vec3) {
      const d = normalize(direction);
      if (kind === 'white') {
        return { x: 1, y: 1, z: 1 };
      }
      if (kind === 'dark') {
        return { x: 0.02, y: 0.025, z: 0.03 };
      }
      if (kind === 'contrast') {
        const bright = Math.abs(Math.sin(Math.atan2(d.z, d.x) * 5)) > 0.45 ? 1 : 0.04;
        return { x: bright, y: bright, z: bright };
      }

      const overhead = Math.max(0, d.y);
      const sideBands = Math.abs(Math.sin(Math.atan2(d.z, d.x) * 6));
      const light = Math.min(1, 0.05 + overhead * 0.75 + (sideBands > 0.82 ? 0.9 : 0));
      return { x: light, y: light * 0.96 + 0.02, z: light * 0.9 + 0.06 };
    },
  };
}

function materialTint(color: string): Vec3 {
  const normalized = color.startsWith('#') ? color.slice(1) : color;
  const value = Number.parseInt(normalized, 16);
  if (!Number.isFinite(value)) {
    return { x: 1, y: 1, z: 1 };
  }
  return {
    x: Math.max(0.2, ((value >> 16) & 255) / 255),
    y: Math.max(0.2, ((value >> 8) & 255) / 255),
    z: Math.max(0.2, (value & 255) / 255),
  };
}

function multiply(a: Vec3, b: Vec3): Vec3 {
  return { x: a.x * b.x, y: a.y * b.y, z: a.z * b.z };
}
