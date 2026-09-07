import { describe, expect, it } from 'vitest';
import { APP_SETTINGS_STORAGE_KEY, defaultAppSettings, loadAppSettings, saveAppSettings } from './AppSettings';

describe('AppSettings', () => {
  it('loads validated appearance preferences', () => {
    const storage = {
      getItem: () => JSON.stringify({ highVisibility: true, density: 'compact', textSize: 'large', reducedMotion: true }),
    };

    expect(loadAppSettings(storage)).toEqual({ highVisibility: true, density: 'compact', textSize: 'large', reducedMotion: true });
  });

  it('falls back safely when stored settings are invalid', () => {
    expect(loadAppSettings({ getItem: () => '{invalid' })).toEqual(defaultAppSettings);
    expect(loadAppSettings({ getItem: () => JSON.stringify({ density: 'unknown' }) })).toEqual(defaultAppSettings);
  });

  it('persists settings under the versioned application key', () => {
    let storedKey = '';
    let storedValue = '';
    saveAppSettings({ ...defaultAppSettings, highVisibility: true }, {
      setItem: (key, value) => {
        storedKey = key;
        storedValue = value;
      },
    });

    expect(storedKey).toBe(APP_SETTINGS_STORAGE_KEY);
    expect(JSON.parse(storedValue).highVisibility).toBe(true);
  });
});
