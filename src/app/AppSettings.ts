export type InterfaceDensity = 'comfortable' | 'compact';
export type InterfaceTextSize = 'normal' | 'large';
export type InterfaceVisibility = 'standard' | 'high' | 'strong';
export type AppTheme = 'deepOcean' | 'graphite' | 'light';
export type GridContrast = 'soft' | 'strong';

export interface AppSettings {
  readonly visibility: InterfaceVisibility;
  readonly theme: AppTheme;
  readonly density: InterfaceDensity;
  readonly textSize: InterfaceTextSize;
  readonly gridContrast: GridContrast;
  readonly showStatusBar: boolean;
  readonly reducedMotion: boolean;
}

export const APP_SETTINGS_STORAGE_KEY = 'v90-fantasy-designer.settings.v1';

export const defaultAppSettings: AppSettings = {
  visibility: 'standard',
  theme: 'deepOcean',
  density: 'comfortable',
  textSize: 'normal',
  gridContrast: 'soft',
  showStatusBar: true,
  reducedMotion: false,
};

export function loadAppSettings(storage?: Pick<Storage, 'getItem'>): AppSettings {
  if (!storage) {
    return defaultAppSettings;
  }
  try {
    const raw = storage.getItem(APP_SETTINGS_STORAGE_KEY);
    if (!raw) {
      return defaultAppSettings;
    }
    return normalizeAppSettings(JSON.parse(raw));
  } catch {
    return defaultAppSettings;
  }
}

export function normalizeAppSettings(value: unknown): AppSettings {
  const settings = (value ?? {}) as Partial<AppSettings> & { highVisibility?: boolean };
  return {
    visibility: isVisibility(settings.visibility) ? settings.visibility : settings.highVisibility ? 'high' : 'standard',
    theme: isTheme(settings.theme) ? settings.theme : 'deepOcean',
    density: settings.density === 'compact' ? 'compact' : 'comfortable',
    textSize: settings.textSize === 'large' ? 'large' : 'normal',
    gridContrast: settings.gridContrast === 'strong' ? 'strong' : 'soft',
    showStatusBar: settings.showStatusBar !== false,
    reducedMotion: settings.reducedMotion === true,
  };
}

function isVisibility(value: unknown): value is InterfaceVisibility {
  return value === 'standard' || value === 'high' || value === 'strong';
}

function isTheme(value: unknown): value is AppTheme {
  return value === 'deepOcean' || value === 'graphite' || value === 'light';
}

export function saveAppSettings(settings: AppSettings, storage?: Pick<Storage, 'setItem'>) {
  if (!storage) {
    return;
  }
  try {
    storage.setItem(APP_SETTINGS_STORAGE_KEY, JSON.stringify(settings));
  } catch {
    // Preferences remain active for this session when storage is unavailable.
  }
}
