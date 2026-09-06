import type { Vec3 } from './GemGeometry';

export interface CoordinateSystem {
  readonly origin: Vec3;
  readonly xAxis: Vec3;
  readonly yAxis: Vec3;
  readonly zAxis: Vec3;
}
