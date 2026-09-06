export { OpticalBVH, type OpticalHit, type OpticalRay } from './OpticalBVH';
export {
  AIR_IOR,
  criticalAngleDeg,
  fresnelDielectric,
  reflectDirection,
  refractDirection,
} from './OpticalMath';
export {
  OpticalTracer,
  createStudioOpticalEnvironment,
  defaultOpticalTraceOptions,
  type OpticalEnvironment,
  type OpticalTraceOptions,
  type OpticalTraceResult,
} from './OpticalTracer';
