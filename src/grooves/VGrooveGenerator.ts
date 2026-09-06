import type { FacetFrame } from '../geometry/FacetFrame';
import type { Vec3 } from '../geometry/GemGeometry';
import { add, cross, distanceSquared, length, normalize, scale, subtract, triangleNormal } from '../geometry/vectorMath';
import type { WorldCutPath } from '../patterns/placement/PatternPlacement';
import type { GroovePreviewGeometry, GroovePreviewTriangle, GrooveSurfaceGuide } from './GroovePreviewGeometry';
import { calculateVGrooveDimensions, type VGrooveSettings } from './VGrooveSettings';

const MIN_SEGMENT_LENGTH_MM = 1e-9;

export function generateVGroovePreviewGeometry(
  cutPaths: readonly WorldCutPath[],
  frame: Pick<FacetFrame, 'normal'>,
  settings: VGrooveSettings,
): GroovePreviewGeometry {
  const normal = normalize(frame.normal);
  const dimensions = calculateVGrooveDimensions(settings);
  const vertices: Vec3[] = [];
  const triangles: GroovePreviewTriangle[] = [];
  const centerLines: WorldCutPath[] = [];
  const surfaceGuides: GrooveSurfaceGuide[] = [];
  let debugVectors: GroovePreviewGeometry['debugVectors'];

  if (dimensions.depthMm <= 0 || dimensions.halfWidthMm <= 0 || length(normal) <= 0) {
    return { vertices, triangles, centerLines, surfaceGuides, outwardNormal: normal, depthMm: dimensions.depthMm };
  }

  for (const path of cutPaths) {
    if (path.points.length < 2) {
      continue;
    }

    const retainedPoints: Vec3[] = [];
    for (let index = 0; index + 1 < path.points.length; index += 1) {
      const start = path.points[index];
      const end = path.points[index + 1];
      if (distanceSquared(start, end) <= MIN_SEGMENT_LENGTH_MM * MIN_SEGMENT_LENGTH_MM) {
        continue;
      }

      retainedPoints.push(start);
      if (index === path.points.length - 2) {
        retainedPoints.push(end);
      }
      const segmentVectors = addGrooveSegment(vertices, triangles, start, end, normal, dimensions.depthMm, dimensions.halfWidthMm);
      if (segmentVectors) {
        surfaceGuides.push({
          startLeft: add(start, scale(segmentVectors.sideways, -dimensions.halfWidthMm)),
          startCenter: start,
          startRight: add(start, scale(segmentVectors.sideways, dimensions.halfWidthMm)),
          endLeft: add(end, scale(segmentVectors.sideways, -dimensions.halfWidthMm)),
          endCenter: end,
          endRight: add(end, scale(segmentVectors.sideways, dimensions.halfWidthMm)),
        });
      }
      debugVectors ??= segmentVectors
        ? {
            origin: scale(add(start, end), 0.5),
            tangent: segmentVectors.tangent,
            sideways: segmentVectors.sideways,
            outwardNormal: normal,
            insideDirection: scale(normal, -1),
          }
        : undefined;
    }

    if (retainedPoints.length >= 2) {
      centerLines.push({ points: retainedPoints });
    }
  }

  return {
    vertices,
    triangles,
    centerLines,
    surfaceGuides,
    outwardNormal: normal,
    depthMm: dimensions.depthMm,
    debugVectors,
  };
}

function addGrooveSegment(
  vertices: Vec3[],
  triangles: GroovePreviewTriangle[],
  start: Vec3,
  end: Vec3,
  normal: Vec3,
  depthMm: number,
  halfWidthMm: number,
): { readonly tangent: Vec3; readonly sideways: Vec3 } | undefined {
  const tangent = normalize(subtract(end, start));
  const sideways = normalize(cross(tangent, normal));
  if (length(sideways) <= 0) {
    return undefined;
  }

  const startLeft = add(start, scale(sideways, -halfWidthMm));
  const startRight = add(start, scale(sideways, halfWidthMm));
  const startBottom = add(start, scale(normal, -depthMm));
  const endLeft = add(end, scale(sideways, -halfWidthMm));
  const endRight = add(end, scale(sideways, halfWidthMm));
  const endBottom = add(end, scale(normal, -depthMm));

  const base = vertices.length;
  vertices.push(startLeft, startBottom, startRight, endLeft, endBottom, endRight);

  addTriangle(vertices, triangles, base + 0, base + 3, base + 4);
  addTriangle(vertices, triangles, base + 0, base + 4, base + 1);
  addTriangle(vertices, triangles, base + 1, base + 4, base + 5);
  addTriangle(vertices, triangles, base + 1, base + 5, base + 2);
  addTriangle(vertices, triangles, base + 0, base + 1, base + 2);
  addTriangle(vertices, triangles, base + 3, base + 5, base + 4);
  return { tangent, sideways };
}

function addTriangle(
  vertices: readonly Vec3[],
  triangles: GroovePreviewTriangle[],
  a: number,
  b: number,
  c: number,
) {
  triangles.push({
    a,
    b,
    c,
    normal: triangleNormal(vertices[a], vertices[b], vertices[c]),
  });
}
