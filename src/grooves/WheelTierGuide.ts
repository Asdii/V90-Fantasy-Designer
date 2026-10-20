import type { Vec3 } from '../geometry/GemGeometry';

export interface WheelTierGuideInput {
  readonly depthMm: number;
  readonly wheelDiameterMm: number;
  readonly tierAngleDeg: number;
  readonly facetNormal?: Vec3;
}

export interface WheelTierGuideResult {
  readonly wheelRadiusMm: number;
  readonly facetAngleDeg?: number;
  readonly runoutAlongFacetMm: number;
  readonly radialProjectionMm: number;
  readonly estimatedTierAxialHeightMm: number;
  readonly estimatedTierSurfaceWidthMm: number;
  readonly depthWithinWheelRadius: boolean;
}

const DEG_TO_RAD = Math.PI / 180;

/**
 * Estimates the room required for the circular entry/exit of a physical V wheel.
 * Tier dimensions assume the cut reaches the tier perpendicular to its inner edge.
 */
export function calculateWheelTierGuide(input: WheelTierGuideInput): WheelTierGuideResult {
  const wheelDiameterMm = clampFinite(input.wheelDiameterMm, 0.001, 1000, 20);
  const wheelRadiusMm = wheelDiameterMm / 2;
  const depthMm = Math.max(0, Number.isFinite(input.depthMm) ? input.depthMm : 0);
  const calculationDepthMm = Math.min(depthMm, wheelRadiusMm);
  const tierAngleDeg = clampFinite(input.tierAngleDeg, 0.001, 89.999, 45);
  const facetAngleDeg = input.facetNormal ? calculateFacetAngleFromHorizontal(input.facetNormal) : undefined;
  const runoutAlongFacetMm = Math.sqrt(Math.max(0, 2 * wheelRadiusMm * calculationDepthMm - calculationDepthMm ** 2));
  const radialProjectionMm = runoutAlongFacetMm * Math.cos((facetAngleDeg ?? 0) * DEG_TO_RAD);
  const tierAngleRad = tierAngleDeg * DEG_TO_RAD;

  return {
    wheelRadiusMm,
    facetAngleDeg,
    runoutAlongFacetMm,
    radialProjectionMm,
    estimatedTierAxialHeightMm: radialProjectionMm * Math.tan(tierAngleRad),
    estimatedTierSurfaceWidthMm: radialProjectionMm / Math.cos(tierAngleRad),
    depthWithinWheelRadius: depthMm <= wheelRadiusMm,
  };
}

export function calculateFacetAngleFromHorizontal(normal: Vec3): number {
  const magnitude = Math.hypot(normal.x, normal.y, normal.z);
  if (magnitude <= 1e-12) {
    return 0;
  }
  const verticalComponent = Math.min(1, Math.max(0, Math.abs(normal.y) / magnitude));
  return Math.acos(verticalComponent) / DEG_TO_RAD;
}

function clampFinite(value: number, min: number, max: number, fallback: number) {
  return Math.min(max, Math.max(min, Number.isFinite(value) ? value : fallback));
}
