import type { Vec3 } from '../geometry/GemGeometry';
import type { WorldCutPath } from '../patterns/placement/PatternPlacement';

export interface GroovePreviewTriangle {
  readonly a: number;
  readonly b: number;
  readonly c: number;
  readonly normal: Vec3;
}

export interface GroovePreviewGeometry {
  readonly vertices: readonly Vec3[];
  readonly triangles: readonly GroovePreviewTriangle[];
  readonly centerLines: readonly WorldCutPath[];
  readonly surfaceGuides?: readonly GrooveSurfaceGuide[];
  readonly outwardNormal?: Vec3;
  readonly depthMm?: number;
  readonly debugVectors?: GrooveDebugVectors;
}

export interface GrooveSurfaceGuide {
  readonly startLeft: Vec3;
  readonly startCenter: Vec3;
  readonly startRight: Vec3;
  readonly endLeft: Vec3;
  readonly endCenter: Vec3;
  readonly endRight: Vec3;
}

export interface GrooveDebugVectors {
  readonly origin: Vec3;
  readonly tangent: Vec3;
  readonly sideways: Vec3;
  readonly outwardNormal: Vec3;
  readonly insideDirection: Vec3;
}
