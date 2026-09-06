import type { Facet } from './Facet';
import type { GemGeometry } from './GemGeometry';
import { worldToLocal } from './CoordinateTransforms';
import { createFacetFrame, type FacetFrame } from './FacetFrame';

export interface Vec2Local {
  readonly u: number;
  readonly v: number;
}

export interface FacetLocalBounds {
  readonly minU: number;
  readonly maxU: number;
  readonly minV: number;
  readonly maxV: number;
  readonly width: number;
  readonly height: number;
}

export interface FacetLocalGeometry {
  readonly frame: FacetFrame;
  readonly boundary: readonly Vec2Local[];
  readonly bounds: FacetLocalBounds;
}

export function createFacetLocalGeometry(geometry: GemGeometry, facet: Facet): FacetLocalGeometry {
  const frame = createFacetFrame(geometry, facet);
  const boundary = facet.boundaryVertexIndices.map((vertexIndex) => {
    const local = worldToLocal(frame, geometry.vertices[vertexIndex]);
    return { u: local.u, v: local.v };
  });

  return {
    frame,
    boundary,
    bounds: calculateLocalBounds(boundary),
  };
}

function calculateLocalBounds(boundary: readonly Vec2Local[]): FacetLocalBounds {
  if (boundary.length === 0) {
    return { minU: 0, maxU: 0, minV: 0, maxV: 0, width: 0, height: 0 };
  }

  let minU = boundary[0].u;
  let maxU = boundary[0].u;
  let minV = boundary[0].v;
  let maxV = boundary[0].v;

  for (const point of boundary) {
    minU = Math.min(minU, point.u);
    maxU = Math.max(maxU, point.u);
    minV = Math.min(minV, point.v);
    maxV = Math.max(maxV, point.v);
  }

  return {
    minU,
    maxU,
    minV,
    maxV,
    width: maxU - minU,
    height: maxV - minV,
  };
}
