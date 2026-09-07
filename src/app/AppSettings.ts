export type InterfaceDensity = 'comfortable' | 'compact';
export type InterfaceTextSize = 'standard' | 'large';

export interface AppSettings {
  readonly highVisibility: boolean;
  readonly density: InterfaceDensity;
  readonly textSize: InterfaceTextSize;
  readonly reducedMotion: boolean;
}

export const APP_SETTINGS_STORAGE_KEY = 'v90-fantasy-designer.settings.v1';

export const defaultAppSettings: AppSettings = {
  highVisibility: false,
  density: 'comfortable',
  textSize: 'standard',
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
    const value = JSON.parse(raw) as Partial<AppSettings>;
    return {
      highVisibility: value.highVisibility === true,
      density: value.density === 'compact' ? 'compact' : 'comfortable',
      textSize: value.textSize === 'large' ? 'large' : 'standard',
      reducedMotion: value.reducedMotion === true,
    };
  } catch {
    return defaultAppSettings;
  }
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
