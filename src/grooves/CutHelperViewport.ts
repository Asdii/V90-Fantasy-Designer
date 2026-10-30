import type { FacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import type { CutHelperStep } from './CutHelper';

/** One viewport for the entire sequence; exported verbatim to MicroFantasy. */
export function createCutHelperViewport(localGeometry: FacetLocalGeometry, steps: readonly CutHelperStep[]) {
  const diagonal = Math.max(Math.hypot(localGeometry.bounds.width, localGeometry.bounds.height), 0.5);
  const facetRadius = Math.max(...localGeometry.boundary.map((point) => Math.hypot(point.u, point.v)), diagonal / 2);
  const cutRadius = steps.reduce((maximum, step) => {
    const segments = step.instruction.visibleSegments.length > 0 ? step.instruction.visibleSegments : [step.instruction.segment];
    return segments.reduce((max, segment) => Math.max(max,
      Math.hypot(segment.start.u, segment.start.v), Math.hypot(segment.end.u, segment.end.v)), maximum);
  }, 0);
  const widestGroove = steps.reduce((maximum, step) => Math.max(maximum, step.grooveWidthMm), 0);
  const contentRadius = Math.max(facetRadius, cutRadius);
  const wheelRadius = Math.max(contentRadius * 1.18, contentRadius + widestGroove * 3, 0.5);
  const extent = wheelRadius * 1.2;
  return { x: -extent, y: -extent, width: extent * 2, height: extent * 2,
    wheelRadius, extent, hairline: Math.max(diagonal * 0.0025, 0.01),
    viewBox: `${-extent} ${-extent} ${extent * 2} ${extent * 2}` };
}
