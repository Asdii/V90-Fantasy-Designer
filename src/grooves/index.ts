export type { GroovePreviewGeometry, GroovePreviewTriangle, GrooveSurfaceGuide } from './GroovePreviewGeometry';
export { generateVGrooveCutterGeometry } from './VGrooveCutterGeometry';
export { generateVGroovePreviewGeometry } from './VGrooveGenerator';
export {
  calculateCutAngleDeg,
  calculateCutHelperPatternOffset,
  calculateCutHelperStageRotation,
  calculateLineDistanceFromOriginMm,
  createCutInstructions,
  rebaseCutInstruction,
  type CutHelperSnapshot,
  type CutHelperDirection,
  type CutInstruction,
} from './CutHelper';
export {
  calculateVGrooveDimensions,
  clampIncludedAngle,
  defaultVGrooveSettings,
  type VGrooveCutterPreset,
  type VGrooveDisplayMode,
  type VGrooveSettings,
} from './VGrooveSettings';
