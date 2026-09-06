import type { GemEnvironmentPreset } from '../EnvironmentPreset';

interface IJewelEnvironmentData {
  readonly background: string;
  readonly primary: string;
  readonly secondary: string;
}

const backgrounds: Record<GemEnvironmentPreset, string> = {
  gemStudio: '#17191d',
  brightStudio: '#e9edf2',
  darkStudio: '#050608',
  highContrast: '#0b0b0b',
};

/** Builds local equirectangular studio maps; no remote HDR asset is required at runtime. */
export function createIJewelEnvironment(preset: GemEnvironmentPreset): IJewelEnvironmentData {
  return {
    background: backgrounds[preset],
    primary: createStudioMap(preset, false),
    secondary: createStudioMap(preset, true),
  };
}

function createStudioMap(preset: GemEnvironmentPreset, secondary: boolean) {
  const canvas = document.createElement('canvas');
  canvas.width = 1024;
  canvas.height = 512;
  const context = canvas.getContext('2d');
  if (!context) {
    throw new Error('Unable to create the iJewel studio environment.');
  }

  context.fillStyle = preset === 'brightStudio' ? '#dce4ee' : '#07090d';
  context.fillRect(0, 0, canvas.width, canvas.height);

  const panels = panelLayout(preset, secondary);
  for (const panel of panels) {
    context.fillStyle = panel.color;
    context.fillRect(
      panel.x * canvas.width,
      panel.y * canvas.height,
      panel.width * canvas.width,
      panel.height * canvas.height,
    );
  }

  return canvas.toDataURL('image/png');
}

function panelLayout(preset: GemEnvironmentPreset, secondary: boolean) {
  const bright = preset === 'brightStudio' ? '#ffffff' : '#f4f8ff';
  const dim = preset === 'highContrast' ? '#000000' : '#151922';
  const shift = secondary ? 0.14 : 0;
  return [
    { x: (0.03 + shift) % 0.82, y: 0.12, width: 0.16, height: 0.68, color: bright },
    { x: (0.34 + shift) % 0.82, y: 0.05, width: 0.1, height: 0.42, color: dim },
    { x: (0.56 + shift) % 0.82, y: 0.25, width: 0.2, height: 0.58, color: bright },
    { x: (0.84 + shift) % 0.9, y: 0.08, width: 0.08, height: 0.78, color: dim },
  ];
}
