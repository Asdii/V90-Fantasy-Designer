import type { Facet } from './Facet';
import type { GemGeometry, Vec3 } from './GemGeometry';
import { cross, dot, length, normalize, scale, subtract } from './vectorMath';

export interface FacetFrame {
  readonly origin: Vec3;
  readonly uAxis: Vec3;
  readonly vAxis: Vec3;
  readonly normal: Vec3;
}

const AXIS_EPSILON = 1e-12;

export function createFacetFrame(geometry: GemGeometry, facet: Facet): FacetFrame {
  const normal = normalize(facet.normal);
  const uCandidate = createBoundaryAlignedUAxis(geometry, facet, normal) ?? createFallbackUAxis(normal);
  const vAxis = normalize(cross(normal, uCandidate));
  const uAxis = normalize(cross(vAxis, normal));

  return {
    origin: facet.centroid,
    uAxis,
    vAxis,
    normal,
  };
}

function createBoundaryAlignedUAxis(geometry: GemGeometry, facet: Facet, normal: Vec3): Vec3 | undefined {
  const edge = chooseDeterministicLongestBoundaryEdge(geometry, facet);
  if (!edge) {
    return undefined;
  }

  const a = geometry.vertices[edge.a];
  const b = geometry.vertices[edge.b];
  const [from, to] = compareVecLexicographic(a, b) <= 0 ? [a, b] : [b, a];
  const direction = subtract(to, from);
  const projected = projectVectorOntoPlane(direction, normal);

  if (length(projected) <= AXIS_EPSILON) {
    return undefined;
  }

  return normalize(projected);
}

function chooseDeterministicLongestBoundaryEdge(geometry: GemGeometry, facet: Facet) {
  let selected = facet.boundaryEdges[0];
  let selectedLength = selected ? edgeLengthSquared(geometry, selected.a, selected.b) : -Infinity;
  let selectedKey = selected ? canonicalEdgeCoordinateKey(geometry, selected.a, selected.b) : '';

  for (const edge of facet.boundaryEdges.slice(1)) {
    const candidateLength = edgeLengthSquared(geometry, edge.a, edge.b);
    const candidateKey = canonicalEdgeCoordinateKey(geometry, edge.a, edge.b);
    const sameLength = Math.abs(candidateLength - selectedLength) <= AXIS_EPSILON;

    if (candidateLength > selectedLength + AXIS_EPSILON || (sameLength && candidateKey < selectedKey)) {
      selected = edge;
      selectedLength = candidateLength;
      selectedKey = candidateKey;
    }
  }

  return selected;
}

function edgeLengthSquared(geometry: GemGeometry, aIndex: number, bIndex: number) {
  const a = geometry.vertices[aIndex];
  const b = geometry.vertices[bIndex];
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const dz = b.z - a.z;
  return dx * dx + dy * dy + dz * dz;
}

function canonicalEdgeCoordinateKey(geometry: GemGeometry, aIndex: number, bIndex: number) {
  const a = geometry.vertices[aIndex];
  const b = geometry.vertices[bIndex];
  const [first, second] = compareVecLexicographic(a, b) <= 0 ? [a, b] : [b, a];
  return `${formatKeyNumber(first.x)}:${formatKeyNumber(first.y)}:${formatKeyNumber(first.z)}|${formatKeyNumber(
    second.x,
  )}:${formatKeyNumber(second.y)}:${formatKeyNumber(second.z)}`;
}

function compareVecLexicographic(a: Vec3, b: Vec3) {
  if (a.x !== b.x) {
    return a.x - b.x;
  }
  if (a.y !== b.y) {
    return a.y - b.y;
  }
  return a.z - b.z;
}

function formatKeyNumber(value: number) {
  return value.toPrecision(17);
}

function createFallbackUAxis(normal: Vec3): Vec3 {
  const candidates = [
    { x: 1, y: 0, z: 0 },
    { x: 0, y: 1, z: 0 },
    { x: 0, y: 0, z: 1 },
  ];
  const axis = candidates.reduce((best, candidate) =>
    Math.abs(dot(candidate, normal)) < Math.abs(dot(best, normal)) ? candidate : best,
  );
  return normalize(projectVectorOntoPlane(axis, normal));
}

function projectVectorOntoPlane(vector: Vec3, normal: Vec3): Vec3 {
  return subtract(vector, scale(normal, dot(vector, normal)));
}
