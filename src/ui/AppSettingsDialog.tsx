import { useEffect, type ReactNode } from 'react';
import type { AppSettings, InterfaceDensity, InterfaceTextSize } from '../app/AppSettings';

interface AppSettingsDialogProps {
  readonly settings: AppSettings;
  readonly onChange: (settings: AppSettings) => void;
  readonly onClose: () => void;
}

export function AppSettingsDialog({ settings, onChange, onClose }: AppSettingsDialogProps) {
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  return (
    <div className="settingsBackdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section className="settingsDialog" role="dialog" aria-modal="true" aria-labelledby="settings-title">
        <header className="settingsHeader">
          <div>
            <h2 id="settings-title">App Settings</h2>
            <p>Appearance</p>
          </div>
          <button className="toolbarButton" onClick={onClose}>Close</button>
        </header>

        <div className="settingsBody">
          <SettingRow label="High visibility">
            <label className="settingsToggle">
              <input
                type="checkbox"
                checked={settings.highVisibility}
                onChange={(event) => onChange({ ...settings, highVisibility: event.target.checked })}
              />
              Strong panel borders
            </label>
          </SettingRow>
          <SettingRow label="Control density">
            <SegmentedSetting<InterfaceDensity>
              value={settings.density}
              options={[['comfortable', 'Comfortable'], ['compact', 'Compact']]}
              onChange={(density) => onChange({ ...settings, density })}
            />
          </SettingRow>
          <SettingRow label="Text size">
            <SegmentedSetting<InterfaceTextSize>
              value={settings.textSize}
              options={[['standard', 'Standard'], ['large', 'Large']]}
              onChange={(textSize) => onChange({ ...settings, textSize })}
            />
          </SettingRow>
          <SettingRow label="Motion">
            <label className="settingsToggle">
              <input
                type="checkbox"
                checked={settings.reducedMotion}
                onChange={(event) => onChange({ ...settings, reducedMotion: event.target.checked })}
              />
              Reduce interface motion
            </label>
          </SettingRow>
        </div>
      </section>
    </div>
  );
}

function SettingRow({ label, children }: { readonly label: string; readonly children: ReactNode }) {
  return (
    <div className="settingsRow">
      <strong>{label}</strong>
      {children}
    </div>
  );
}

function SegmentedSetting<T extends string>({ value, options, onChange }: {
  readonly value: T;
  readonly options: readonly (readonly [T, string])[];
  readonly onChange: (value: T) => void;
}) {
  return (
    <div className="settingsSegments" role="group">
      {options.map(([option, label]) => (
        <button key={option} className={value === option ? 'toolbarButton active' : 'toolbarButton'} onClick={() => onChange(option)}>
          {label}
        </button>
      ))}
    </div>
  );
}
