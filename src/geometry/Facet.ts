import type { Edge, Vec3 } from './GemGeometry';
import type { Plane } from './Plane';

export interface Facet {
  readonly id: number;
  readonly triangleIndices: readonly number[];
  readonly normal: Vec3;
  readonly plane: Plane;
  readonly area: number;
  readonly centroid: Vec3;
  readonly boundaryEdges: readonly Edge[];
  readonly boundaryVertexIndices: readonly number[];
  readonly boundaryLoops: readonly (readonly number[])[];
}
