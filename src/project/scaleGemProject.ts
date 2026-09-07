import { scaleGemGeometry } from '../geometry/FacetMeasurement';
import type { FacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import type { Vec3 } from '../geometry/GemGeometry';
import type { LineSegment2D } from '../patterns/Pattern';
import type { WorldCutPath } from '../patterns/placement/PatternPlacement';
import type { CutInstruction } from '../grooves';
import type { CutOperation, GemProject } from './GemProject';

export function scaleGemProject(project: GemProject, factor: number): GemProject {
  const anchor = project.sourceGeometry?.boundingBox.center
    ?? project.geometry?.boundingBox.center
    ?? { x: 0, y: 0, z: 0 };
  return {
    ...project,
    sourceGeometry: project.sourceGeometry ? scaleGemGeometry(project.sourceGeometry, factor, anchor) : undefined,
    geometry: project.geometry ? scaleGemGeometry(project.geometry, factor, anchor) : undefined,
    cutOperations: project.cutOperations.map((operation) => scaleCutOperation(operation, factor, anchor)),
  };
}

function scaleCutOperation(operation: CutOperation, factor: number, anchor: Vec3): CutOperation {
  return {
    ...operation,
    placement: {
      ...operation.placement,
      offsetX: operation.placement.offsetX * factor,
      offsetY: operation.placement.offsetY * factor,
      scale: operation.placement.scale * factor,
    },
    grooveSettings: {
      ...operation.grooveSettings,
      depthMm: operation.grooveSettings.depthMm * factor,
    },
    worldCutPaths: operation.worldCutPaths.map((path) => scaleWorldCutPath(path, factor, anchor)),
    cutHelper: {
      localGeometry: scaleLocalGeometry(operation.cutHelper.localGeometry, factor, anchor),
      instructions: operation.cutHelper.instructions.map((instruction) => scaleInstruction(instruction, factor)),
      grooveWidthMm: operation.cutHelper.grooveWidthMm * factor,
    },
  };
}

function scaleWorldCutPath(path: WorldCutPath, factor: number, anchor: Vec3): WorldCutPath {
  return { points: path.points.map((point) => scaleVec3Around(point, factor, anchor)) };
}

function scaleLocalGeometry(local: FacetLocalGeometry, factor: number, anchor: Vec3): FacetLocalGeometry {
  return {
    frame: {
      ...local.frame,
      origin: scaleVec3Around(local.frame.origin, factor, anchor),
    },
    boundary: local.boundary.map((point) => ({ u: point.u * factor, v: point.v * factor })),
    bounds: {
      minU: local.bounds.minU * factor,
      maxU: local.bounds.maxU * factor,
      minV: local.bounds.minV * factor,
      maxV: local.bounds.maxV * factor,
      width: local.bounds.width * factor,
      height: local.bounds.height * factor,
    },
  };
}

function scaleInstruction(instruction: CutInstruction, factor: number): CutInstruction {
  return {
    ...instruction,
    distanceFromCenterMm: instruction.distanceFromCenterMm * factor,
    depthMm: instruction.depthMm * factor,
    segment: scaleSegment(instruction.segment, factor),
    visibleSegments: instruction.visibleSegments.map((segment) => scaleSegment(segment, factor)),
  };
}

function scaleSegment(segment: LineSegment2D, factor: number): LineSegment2D {
  return {
    ...segment,
    start: { u: segment.start.u * factor, v: segment.start.v * factor },
    end: { u: segment.end.u * factor, v: segment.end.v * factor },
  };
}

function scaleVec3Around(point: Vec3, factor: number, anchor: Vec3): Vec3 {
  return {
    x: anchor.x + (point.x - anchor.x) * factor,
    y: anchor.y + (point.y - anchor.y) * factor,
    z: anchor.z + (point.z - anchor.z) * factor,
  };
}
