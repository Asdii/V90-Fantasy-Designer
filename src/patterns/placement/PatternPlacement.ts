import { localToWorld } from '../../geometry/CoordinateTransforms';
import type { FacetLocalGeometry } from '../../geometry/FacetLocalGeometry';
import type { Vec3 } from '../../geometry/GemGeometry';
import type { LineSegment2D } from '../Pattern';
import { clipSegmentToFacetPolygon } from '../PatternClipping';
import { patternToCutPaths } from '../geometry/pathConversion';
import { calculateDesignPatternBounds } from '../geometry/bounds';
import type { CutPath, DesignPattern, Vec2 } from '../model/PatternModel';

const INFINITE_CUT_LINE_EXTENSION_FACTOR = 4;

export interface PatternPlacement {
  readonly facetId: number;
  readonly offsetX: number;
  readonly offsetY: number;
  readonly rotationDeg: number;
  readonly scale: number;
}

export interface ClippedPlacedPattern {
  readonly insideSegments: readonly LineSegment2D[];
  readonly outsideSegments: readonly LineSegment2D[];
}

export interface WorldCutPath {
  readonly points: readonly Vec3[];
}

export function createDefaultPatternPlacement(facetId: number): PatternPlacement {
  return {
    facetId,
    offsetX: 0,
    offsetY: 0,
    rotationDeg: 0,
    scale: 1,
  };
}

export function centerPatternPlacement(_pattern: DesignPattern, placement: PatternPlacement): PatternPlacement {
  return {
    ...placement,
    offsetX: 0,
    offsetY: 0,
  };
}

export function fitPatternPlacementToFacetBounds(
  pattern: DesignPattern,
  placement: PatternPlacement,
  facetBounds: {
    readonly width: number;
    readonly height: number;
    readonly minU?: number;
    readonly maxU?: number;
    readonly minV?: number;
    readonly maxV?: number;
  },
  margin = 0.95,
): PatternPlacement {
  const bounds = calculateDesignPatternBounds(pattern);
  if (bounds.width <= 0 && bounds.height <= 0) {
    return centerPatternPlacement(pattern, placement);
  }

  const radians = (placement.rotationDeg * Math.PI) / 180;
  const cos = Math.cos(radians);
  const sin = Math.sin(radians);
  const corners = [
    { x: bounds.minX, y: bounds.minY },
    { x: bounds.maxX, y: bounds.minY },
    { x: bounds.maxX, y: bounds.maxY },
    { x: bounds.minX, y: bounds.maxY },
  ].map((point) => ({
    u: point.x * cos - point.y * sin,
    v: point.x * sin + point.y * cos,
  }));
  const limits = {
    minU: facetBounds.minU ?? -facetBounds.width / 2,
    maxU: facetBounds.maxU ?? facetBounds.width / 2,
    minV: facetBounds.minV ?? -facetBounds.height / 2,
    maxV: facetBounds.maxV ?? facetBounds.height / 2,
  };
  const scaleLimits = corners.flatMap((point) => [
    point.u > 0 ? limits.maxU / point.u : point.u < 0 ? limits.minU / point.u : Infinity,
    point.v > 0 ? limits.maxV / point.v : point.v < 0 ? limits.minV / point.v : Infinity,
  ]).filter((value) => Number.isFinite(value) && value >= 0);
  const scale = (scaleLimits.length > 0 ? Math.min(...scaleLimits) : placement.scale) * margin;
  return centerPatternPlacement(pattern, { ...placement, scale: Number.isFinite(scale) ? scale : placement.scale });
}

export function applyPatternPlacement(point: Vec2, placement: PatternPlacement): { readonly u: number; readonly v: number } {
  const radians = (placement.rotationDeg * Math.PI) / 180;
  const cos = Math.cos(radians);
  const sin = Math.sin(radians);
  const scaledX = point.x * placement.scale;
  const scaledY = point.y * placement.scale;

  return {
    u: scaledX * cos - scaledY * sin + placement.offsetX,
    v: scaledX * sin + scaledY * cos + placement.offsetY,
  };
}

export function clipPatternToFacet(
  pattern: DesignPattern,
  placement: PatternPlacement,
  facetLocalPolygon: readonly { readonly u: number; readonly v: number }[],
  curveSegments = 64,
): ClippedPlacedPattern {
  const insideSegments: LineSegment2D[] = [];
  const outsideSegments: LineSegment2D[] = [];

  for (const segment of patternToPlacedSegments(patternToCutPaths(pattern, curveSegments), placement)) {
    const clipped = clipSegmentToFacetPolygon(segment, facetLocalPolygon);
    insideSegments.push(...clipped.inside);
    outsideSegments.push(...clipped.outside);
  }

  return { insideSegments, outsideSegments };
}

export function patternPlacementToWorldCutPaths(
  pattern: DesignPattern,
  placement: PatternPlacement,
  localGeometry: FacetLocalGeometry,
  visualOffsetNormal = 0,
): WorldCutPath[] {
  const effectiveSegments = patternPlacementToFacetCutSegments(pattern, placement, localGeometry.boundary);
  return effectiveSegments.map((segment) => ({
    points: [
      localToWorld(localGeometry.frame, segment.start.u, segment.start.v, visualOffsetNormal),
      localToWorld(localGeometry.frame, segment.end.u, segment.end.v, visualOffsetNormal),
    ],
  }));
}

export function patternPlacementToFacetCutSegments(
  pattern: DesignPattern,
  placement: PatternPlacement,
  facetPolygon: readonly { readonly u: number; readonly v: number }[],
): LineSegment2D[] {
  const segments: LineSegment2D[] = [];

  for (const primitive of pattern.primitives) {
    if (primitive.role !== 'pattern') {
      continue;
    }

    if (primitive.type === 'line') {
      addInfiniteLineSegment(segments, primitive.id, primitive.start, primitive.end, placement, facetPolygon);
      continue;
    }

    if (primitive.type === 'polyline') {
      for (let index = 0; index + 1 < primitive.points.length; index += 1) {
        addInfiniteLineSegment(
          segments,
          `${primitive.id}-${index}`,
          primitive.points[index],
          primitive.points[index + 1],
          placement,
          facetPolygon,
        );
      }
      if (primitive.closed && primitive.points.length > 2) {
        addInfiniteLineSegment(
          segments,
          `${primitive.id}-closed`,
          primitive.points[primitive.points.length - 1],
          primitive.points[0],
          placement,
          facetPolygon,
        );
      }
      continue;
    }

    const curvedPattern: DesignPattern = { ...pattern, primitives: [primitive] };
    for (const segment of patternToPlacedSegments(patternToCutPaths(curvedPattern), placement)) {
      segments.push(...clipSegmentToFacetPolygon(segment, facetPolygon).inside);
    }
  }

  return segments;
}

function addInfiniteLineSegment(
  target: LineSegment2D[],
  id: string,
  start: Vec2,
  end: Vec2,
  placement: PatternPlacement,
  facetPolygon: readonly { readonly u: number; readonly v: number }[],
) {
  const placedStart = applyPatternPlacement(start, placement);
  const placedEnd = applyPatternPlacement(end, placement);
  const extended = extendLineAcrossFacet({ id, start: placedStart, end: placedEnd }, facetPolygon);
  if (extended && clipSegmentToFacetPolygon(extended, facetPolygon).inside.length > 0) {
    target.push(extended);
  }
}

/**
 * Treats a finite pattern edge as an effectively infinite cutter trajectory.
 * The endpoints are placed several facet radii beyond the selected face so CSG
 * end caps never coincide with the facet boundary.
 */
export function extendLineAcrossFacet(
  segment: LineSegment2D,
  facetPolygon: readonly { readonly u: number; readonly v: number }[],
): LineSegment2D | undefined {
  if (facetPolygon.length < 3) {
    return undefined;
  }

  const du = segment.end.u - segment.start.u;
  const dv = segment.end.v - segment.start.v;
  const length = Math.hypot(du, dv);
  if (length <= 1e-12) {
    return undefined;
  }

  const center = {
    u: (segment.start.u + segment.end.u) / 2,
    v: (segment.start.v + segment.end.v) / 2,
  };
  const facetRadius = Math.max(
    ...facetPolygon.map((point) => Math.hypot(point.u - center.u, point.v - center.v)),
  );
  const reach = Math.max(length / 2, facetRadius * INFINITE_CUT_LINE_EXTENSION_FACTOR, 1);
  const direction = { u: du / length, v: dv / length };

  return {
    ...segment,
    start: { u: center.u - direction.u * reach, v: center.v - direction.v * reach },
    end: { u: center.u + direction.u * reach, v: center.v + direction.v * reach },
  };
}

export function patternToPlacedSegments(paths: readonly CutPath[], placement: PatternPlacement): LineSegment2D[] {
  const segments: LineSegment2D[] = [];
  for (const path of paths) {
    for (let index = 0; index + 1 < path.points.length; index += 1) {
      segments.push({
        id: crypto.randomUUID(),
        start: applyPatternPlacement(path.points[index], placement),
        end: applyPatternPlacement(path.points[index + 1], placement),
      });
    }
    if (path.closed && path.points.length > 2) {
      segments.push({
        id: crypto.randomUUID(),
        start: applyPatternPlacement(path.points[path.points.length - 1], placement),
        end: applyPatternPlacement(path.points[0], placement),
      });
    }
  }
  return segments;
}
