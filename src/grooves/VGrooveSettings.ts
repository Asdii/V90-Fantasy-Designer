export interface VGrooveSettings {
  readonly includedAngleDeg: number;
  readonly depthMm: number;
}

export type VGrooveCutterPreset = '60' | '90' | 'custom';

export type VGrooveDisplayMode = 'centerLines' | 'surfaces' | 'both';

export const defaultVGrooveSettings: VGrooveSettings = {
  includedAngleDeg: 90,
  depthMm: 0.05,
};

export function calculateVGrooveDimensions(settings: VGrooveSettings) {
  const includedAngleDeg = clampIncludedAngle(settings.includedAngleDeg);
  const depthMm = Math.max(0, settings.depthMm);
  const halfAngleDeg = includedAngleDeg / 2;
  const halfWidthMm = depthMm * Math.tan((halfAngleDeg * Math.PI) / 180);

  return {
    includedAngleDeg,
    halfAngleDeg,
    depthMm,
    halfWidthMm,
    widthMm: halfWidthMm * 2,
  };
}

export function clampIncludedAngle(value: number) {
  return Math.min(170, Math.max(1, Number.isFinite(value) ? value : 90));
}
