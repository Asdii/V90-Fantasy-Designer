import type { Vec2Local } from '../geometry/FacetLocalGeometry';
import { calculateSignedLineDistanceMm, type CutHelperStep, type CutHelperView } from '../grooves/CutHelper';
import { createCutHelperViewport } from '../grooves/CutHelperViewport';

export interface MobileSegment { readonly start: Vec2Local; readonly end: Vec2Local }
export interface MicroFantasyJob {
  readonly jobId: string;
  readonly name: string;
  readonly units: 'mm';
  readonly steps: readonly { index: number; angleR: number; x: number; depth: number }[];
  readonly cutHelper: {
    readonly version: 1;
    readonly coordinateSystem: 'facet-local-mm-y-up';
    readonly referenceFacetId: number;
    readonly boundary: readonly Vec2Local[];
    readonly viewport: { extent: number; wheelRadius: number; hairline: number };
    readonly initialView: CutHelperView;
    readonly machineCenterXmm: number;
    readonly steps: readonly {
      index: number; operationId: string; operationNumber: number;
      distanceFromCenterMm: number; signedDistanceMm: number; grooveWidthMm: number;
      segment: MobileSegment; visibleSegments: readonly MobileSegment[];
    }[];
  };
}

export function createMicroFantasyJob(
  sequence: readonly CutHelperStep[],
  options: { jobId: string; name: string; view: CutHelperView; machineCenterXmm?: number },
): MicroFantasyJob {
  if (sequence.length === 0) throw new Error('Create at least one cut before sending the Cut Helper.');
  const center = options.machineCenterXmm ?? 0;
  if (!Number.isFinite(center)) throw new Error('The center X position must be a finite number.');
  if (!options.name.trim() || !options.jobId) throw new Error('A job name and ID are required.');
  const viewport = createCutHelperViewport(sequence[0].localGeometry, sequence);
  const point = (p: Vec2Local) => {
    if (!Number.isFinite(p.u) || !Number.isFinite(p.v)) throw new Error('Invalid Cut Helper coordinates.');
    return { u: p.u, v: p.v };
  };
  const segment = (s: MobileSegment): MobileSegment => ({ start: point(s.start), end: point(s.end) });
  const steps = sequence.map(({ instruction }, i) => ({
    index: i + 1, angleR: instruction.angleDeg,
    x: center + calculateSignedLineDistanceMm(instruction.segment), depth: instruction.depthMm,
  }));
  if (steps.some((s) => ![s.angleR, s.x, s.depth].every(Number.isFinite) || s.depth < 0)) {
    throw new Error('The cutting sequence contains invalid values.');
  }
  return {
    jobId: options.jobId, name: options.name.trim(), units: 'mm', steps,
    cutHelper: {
      version: 1, coordinateSystem: 'facet-local-mm-y-up', referenceFacetId: sequence[0].facetId,
      boundary: sequence[0].localGeometry.boundary.map(point),
      viewport: { extent: viewport.extent, wheelRadius: viewport.wheelRadius, hairline: viewport.hairline },
      initialView: { ...options.view, stepIndex: Math.max(0, Math.min(sequence.length - 1, options.view.stepIndex)) },
      machineCenterXmm: center,
      steps: sequence.map((s, i) => ({
        index: i + 1, operationId: s.operationId, operationNumber: s.operationNumber,
        distanceFromCenterMm: s.instruction.distanceFromCenterMm,
        signedDistanceMm: calculateSignedLineDistanceMm(s.instruction.segment),
        grooveWidthMm: s.grooveWidthMm,
        segment: segment(s.instruction.segment), visibleSegments: s.instruction.visibleSegments.map(segment),
      })),
    },
  };
}
