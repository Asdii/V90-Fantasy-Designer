import type { Facet } from './Facet';

export interface Vec3 {
  readonly x: number;
  readonly y: number;
  readonly z: number;
}

export interface Triangle {
  readonly a: number;
  readonly b: number;
  readonly c: number;
  readonly normal: Vec3;
}

export interface GemGeometry {
  readonly units: 'millimeters';
  readonly vertices: readonly Vec3[];
  readonly triangles: readonly Triangle[];
  readonly edges: readonly Edge[];
  readonly facets: readonly Facet[];
  readonly boundingBox: BoundingBox;
  readonly warnings: readonly GeometryWarning[];
}

export interface Edge {
  readonly a: number;
  readonly b: number;
}

export interface BoundingBox {
  readonly min: Vec3;
  readonly max: Vec3;
  readonly size: Vec3;
  readonly center: Vec3;
}

export interface GeometryWarning {
  readonly code:
    | 'degenerate-triangles'
    | 'open-edges'
    | 'non-manifold-edges'
    | 'inconsistent-winding'
    | 'inverted-winding-corrected';
  readonly message: string;
  readonly count: number;
}
