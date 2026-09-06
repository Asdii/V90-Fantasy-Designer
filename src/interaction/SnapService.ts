import type { GridSnapStep, Pattern, Vec2 } from '../patterns/Pattern';

export interface SnapCandidate {
  readonly point: Vec2;
  readonly screenDistancePx: number;
  readonly priority: number;
}

export const SNAP_DISTANCE_PX = 12;

export function snapPoint(
  rawPoint: Vec2,
  candidates: readonly SnapCandidate[],
  gridStep: GridSnapStep,
  snapEnabled: boolean,
): Vec2 {
  if (!snapEnabled) {
    return rawPoint;
  }

  const candidate = candidates
    .filter((item) => item.screenDistancePx <= SNAP_DISTANCE_PX)
    .sort((a, b) => a.priority - b.priority || a.screenDistancePx - b.screenDistancePx)[0];

  if (candidate) {
    return candidate.point;
  }

  return snapToGrid(rawPoint, gridStep);
}

export function snapToGrid(point: Vec2, gridStep: GridSnapStep): Vec2 {
  const step = gridStepToNumber(gridStep);
  if (!step) {
    return point;
  }

  return {
    u: Math.round(point.u / step) * step,
    v: Math.round(point.v / step) * step,
  };
}

export function gridStepToNumber(gridStep: GridSnapStep): number | undefined {
  if (gridStep === 'off') {
    return undefined;
  }

  return Number(gridStep);
}

export function createPatternEndpointCandidates(pattern?: Pattern): Vec2[] {
  return pattern?.segments.flatMap((segment) => [segment.start, segment.end]) ?? [];
}
