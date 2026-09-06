import type { FacetFrame } from '../geometry/FacetFrame';
import type { Vec3 } from '../geometry/GemGeometry';
import { add, cross, distanceSquared, length, normalize, scale, subtract, triangleNormal } from '../geometry/vectorMath';
import type { WorldCutPath } from '../patterns/placement/PatternPlacement';
import type { GroovePreviewGeometry, GroovePreviewTriangle } from './GroovePreviewGeometry';
import { calculateVGrooveDimensions, type VGrooveSettings } from './VGrooveSettings';

const MIN_SEGMENT_LENGTH_MM = 1e-9;

export function generateVGrooveCutterGeometry(
  cutPaths: readonly WorldCutPath[],
  frame: Pick<FacetFrame, 'normal'>,
  settings: VGrooveSettings,
  topClearanceMm = Math.max(settings.depthMm * 0.08, 0.002),
): GroovePreviewGeometry {
  const normal = normalize(frame.normal);
  const dimensions = calculateVGrooveDimensions(settings);
  const vertices: Vec3[] = [];
  const triangles: GroovePreviewTriangle[] = [];

  for (const path of cutPaths) {
    for (let index = 0; index + 1 < path.points.length; index += 1) {
      addCutterSegment(vertices, triangles, path.points[index], path.points[index + 1], normal, dimensions.depthMm, dimensions.halfWidthMm, topClearanceMm);
    }
  }

  return { vertices, triangles, centerLines: cutPaths };
}

function addCutterSegment(
  vertices: Vec3[],
  triangles: GroovePreviewTriangle[],
  start: Vec3,
  end: Vec3,
  normal: Vec3,
  depthMm: number,
  halfWidthMm: number,
  topClearanceMm: number,
) {
  if (distanceSquared(start, end) <= MIN_SEGMENT_LENGTH_MM * MIN_SEGMENT_LENGTH_MM) {
    return;
  }

  const tangent = normalize(subtract(end, start));
  const sideways = normalize(cross(tangent, normal));
  if (length(sideways) <= 0) {
    return;
  }

  const topOffset = scale(normal, topClearanceMm);
  const startLeft = add(add(start, scale(sideways, -halfWidthMm)), topOffset);
  const startRight = add(add(start, scale(sideways, halfWidthMm)), topOffset);
  const startBottom = add(start, scale(normal, -depthMm));
  const endLeft = add(add(end, scale(sideways, -halfWidthMm)), topOffset);
  const endRight = add(add(end, scale(sideways, halfWidthMm)), topOffset);
  const endBottom = add(end, scale(normal, -depthMm));

  const base = vertices.length;
  vertices.push(startLeft, startBottom, startRight, endLeft, endBottom, endRight);

  addTriangle(vertices, triangles, base + 0, base + 3, base + 4);
  addTriangle(vertices, triangles, base + 0, base + 4, base + 1);
  addTriangle(vertices, triangles, base + 1, base + 4, base + 5);
  addTriangle(vertices, triangles, base + 1, base + 5, base + 2);
  addTriangle(vertices, triangles, base + 0, base + 2, base + 5);
  addTriangle(vertices, triangles, base + 0, base + 5, base + 3);
  addTriangle(vertices, triangles, base + 0, base + 1, base + 2);
  addTriangle(vertices, triangles, base + 3, base + 5, base + 4);
}

function addTriangle(vertices: readonly Vec3[], triangles: GroovePreviewTriangle[], a: number, b: number, c: number) {
  triangles.push({ a, b, c, normal: triangleNormal(vertices[a], vertices[b], vertices[c]) });
}
