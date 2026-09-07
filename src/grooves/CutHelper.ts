import type { FacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import { localToWorld, worldToLocal } from '../geometry/CoordinateTransforms';
import type { LineSegment2D } from '../patterns/Pattern';
import { clipSegmentToFacetPolygon } from '../patterns/PatternClipping';
import type { DesignPattern } from '../patterns/model/PatternModel';
import {
  patternPlacementToFacetCutSegments,
  type PatternPlacement,
} from '../patterns/placement/PatternPlacement';
import type { VGrooveSettings } from './VGrooveSettings';

const DIRECTION_EPSILON = 1e-12;

export interface CutInstruction {
  readonly id: string;
  readonly step: number;
  readonly angleDeg: number;
  readonly distanceFromCenterMm: number;
  readonly depthMm: number;
  readonly segment: LineSegment2D;
  readonly visibleSegments: readonly LineSegment2D[];
}

export interface CutHelperSnapshot {
  readonly localGeometry: FacetLocalGeometry;
  readonly instructions: readonly CutInstruction[];
  readonly grooveWidthMm: number;
}

export type CutHelperDirection = 'horizontal' | 'vertical';

export function calculateCutHelperStageRotation(angleDeg: number, direction: CutHelperDirection) {
  return angleDeg + (direction === 'vertical' ? -90 : 0);
}

export function createCutInstructions(
  pattern: DesignPattern,
  placement: PatternPlacement,
  localGeometry: FacetLocalGeometry,
  settings: VGrooveSettings,
): CutInstruction[] {
  return patternPlacementToFacetCutSegments(pattern, placement, localGeometry.boundary)
    .filter((segment) => segmentLength(segment) > DIRECTION_EPSILON)
    .map((segment, index) => ({
      id: segment.id,
      step: index + 1,
      angleDeg: calculateCutAngleDeg(segment),
      distanceFromCenterMm: calculateLineDistanceFromOriginMm(segment),
      depthMm: settings.depthMm,
      segment,
      visibleSegments: clipSegmentToFacetPolygon(segment, localGeometry.boundary).inside,
    }));
}

export function rebaseCutInstruction(
  instruction: CutInstruction,
  sourceGeometry: FacetLocalGeometry,
  referenceGeometry: FacetLocalGeometry,
): CutInstruction {
  const segment = rebaseSegment(instruction.segment, sourceGeometry, referenceGeometry);
  return {
    ...instruction,
    angleDeg: calculateCutAngleDeg(segment),
    distanceFromCenterMm: calculateLineDistanceFromOriginMm(segment),
    segment,
    visibleSegments: instruction.visibleSegments.map((visible) => rebaseSegment(visible, sourceGeometry, referenceGeometry)),
  };
}

/** Direction from segment start to end, measured counter-clockwise from local +X. */
export function calculateCutAngleDeg(segment: LineSegment2D): number {
  const angle = (Math.atan2(segment.end.v - segment.start.v, segment.end.u - segment.start.u) * 180) / Math.PI;
  const normalized = ((angle % 360) + 360) % 360;
  return Math.abs(normalized - 360) < 1e-10 || Math.abs(normalized) < 1e-10 ? 0 : normalized;
}

/** Unsigned perpendicular distance from facet-local origin to the infinite cut line. */
export function calculateLineDistanceFromOriginMm(segment: LineSegment2D): number {
  const du = segment.end.u - segment.start.u;
  const dv = segment.end.v - segment.start.v;
  const length = Math.hypot(du, dv);
  if (length <= DIRECTION_EPSILON) {
    return 0;
  }
  return Math.abs(segment.start.u * dv - segment.start.v * du) / length;
}

function segmentLength(segment: LineSegment2D) {
  return Math.hypot(segment.end.u - segment.start.u, segment.end.v - segment.start.v);
}

function rebaseSegment(
  segment: LineSegment2D,
  sourceGeometry: FacetLocalGeometry,
  referenceGeometry: FacetLocalGeometry,
): LineSegment2D {
  return {
    ...segment,
    start: rebasePoint(segment.start, sourceGeometry, referenceGeometry),
    end: rebasePoint(segment.end, sourceGeometry, referenceGeometry),
  };
}

function rebasePoint(
  point: LineSegment2D['start'],
  sourceGeometry: FacetLocalGeometry,
  referenceGeometry: FacetLocalGeometry,
) {
  const world = localToWorld(sourceGeometry.frame, point.u, point.v);
  const local = worldToLocal(referenceGeometry.frame, world);
  return { u: local.u, v: local.v };
}
