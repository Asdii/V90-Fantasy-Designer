import type { Facet } from './Facet';
import type { GemGeometry, Vec3 } from './GemGeometry';
import { cross, dot, length, normalize, scale, subtract } from './vectorMath';

export interface FacetFrame {
  readonly origin: Vec3;
  readonly uAxis: Vec3;
  readonly vAxis: Vec3;
  readonly normal: Vec3;
}

const AXIS_EPSILON = 1e-8;
const MODEL_UP_AXIS: Vec3 = { x: 0, y: 1, z: 0 };
const MODEL_FORWARD_AXIS: Vec3 = { x: 0, y: 0, z: 1 };
const MODEL_RIGHT_AXIS: Vec3 = { x: 1, y: 0, z: 0 };

export function createFacetFrame(_geometry: GemGeometry, facet: Facet): FacetFrame {
  const normal = normalize(facet.normal);
  const vCandidate = createModelAlignedVAxis(normal);
  const uAxis = normalize(cross(vCandidate, normal));
  const vAxis = normalize(cross(normal, uAxis));

  return {
    origin: facet.centroid,
    uAxis,
    vAxis,
    normal,
  };
}

function createModelAlignedVAxis(normal: Vec3): Vec3 {
  for (const referenceAxis of [MODEL_UP_AXIS, MODEL_FORWARD_AXIS, MODEL_RIGHT_AXIS]) {
    const projected = projectVectorOntoPlane(referenceAxis, normal);
    if (length(projected) > AXIS_EPSILON) {
      return normalize(projected);
    }
  }

  throw new Error('Could not create a stable local frame for the selected facet.');
}

function projectVectorOntoPlane(vector: Vec3, normal: Vec3): Vec3 {
  return subtract(vector, scale(normal, dot(vector, normal)));
}
