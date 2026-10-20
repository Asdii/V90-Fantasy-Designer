import { describe, expect, it } from 'vitest';
import { APP_SETTINGS_STORAGE_KEY, defaultAppSettings, loadAppSettings, saveAppSettings } from './AppSettings';

describe('AppSettings', () => {
  it('loads validated appearance preferences', () => {
    const storage = {
      getItem: () => JSON.stringify({ highVisibility: true, density: 'compact', textSize: 'large', reducedMotion: true }),
    };

    expect(loadAppSettings(storage)).toEqual({
      visibility: 'high',
      theme: 'deepOcean',
      density: 'compact',
      textSize: 'large',
      gridContrast: 'soft',
      showStatusBar: true,
      reducedMotion: true,
      experimentalWheelTierGuide: false,
      experimentalPatternSymmetryLock: false,
      wheelDiameterMm: 20,
      tierAngleDeg: 45,
    });
  });

  it('normalizes persisted experimental wheel guide settings', () => {
    const settings = loadAppSettings({
      getItem: () => JSON.stringify({
        experimentalWheelTierGuide: true,
        experimentalPatternSymmetryLock: true,
        wheelDiameterMm: 24,
        tierAngleDeg: 45,
      }),
    });

    expect(settings.experimentalWheelTierGuide).toBe(true);
    expect(settings.experimentalPatternSymmetryLock).toBe(true);
    expect(settings.wheelDiameterMm).toBe(24);
    expect(settings.tierAngleDeg).toBe(45);
  });

  it('falls back safely when stored settings are invalid', () => {
    expect(loadAppSettings({ getItem: () => '{invalid' })).toEqual(defaultAppSettings);
    expect(loadAppSettings({ getItem: () => JSON.stringify({ density: 'unknown' }) })).toEqual(defaultAppSettings);
  });

  it('persists settings under the versioned application key', () => {
    let storedKey = '';
    let storedValue = '';
    saveAppSettings({ ...defaultAppSettings, visibility: 'strong' }, {
      setItem: (key, value) => {
        storedKey = key;
        storedValue = value;
      },
    });

    expect(storedKey).toBe(APP_SETTINGS_STORAGE_KEY);
    expect(JSON.parse(storedValue).visibility).toBe('strong');
  });
});
