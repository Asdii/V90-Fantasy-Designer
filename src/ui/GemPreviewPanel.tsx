import type { GemProject } from '../project/GemProject';
import type { GemMaterial } from '../materials/GemMaterial';
import { gemMaterialPresets } from '../materials/GemMaterial';
import type { GemEnvironmentPreset } from '../rendering/EnvironmentPreset';
import type { PatternPlacement } from '../patterns/placement/PatternPlacement';
import {
  calculateVGrooveDimensions,
  type VGrooveCutterPreset,
  type VGrooveDisplayMode,
  type VGrooveSettings,
} from '../grooves';

interface GemPreviewPanelProps {
  readonly project: GemProject;
  readonly selectedFacetId?: number;
  readonly importError?: string;
  readonly material: GemMaterial;
  readonly environmentPreset: GemEnvironmentPreset;
  readonly cleanRender: boolean;
  readonly gemViewMode: 'setup' | 'render';
  readonly placement?: PatternPlacement;
  readonly patternPrimitiveCount: number;
  readonly vGrooveSettings: VGrooveSettings;
  readonly vGrooveCutterPreset: VGrooveCutterPreset;
  readonly vGrooveDisplayMode: VGrooveDisplayMode;
  readonly showVGroovePreview: boolean;
  readonly cutOperationState: { readonly status: 'idle' | 'running' | 'success' | 'error'; readonly message?: string };
  readonly onEnvironmentPresetChange: (environment: GemEnvironmentPreset) => void;
  readonly onCleanRenderChange: (enabled: boolean) => void;
  readonly onMaterialChange: (material: GemMaterial) => void;
  readonly onGemViewModeChange: (mode: 'setup' | 'render') => void;
  readonly onPlacementChange: (placement: PatternPlacement) => void;
  readonly onVGrooveSettingsChange: (settings: VGrooveSettings) => void;
  readonly onVGrooveCutterPresetChange: (preset: VGrooveCutterPreset) => void;
  readonly onVGrooveDisplayModeChange: (mode: VGrooveDisplayMode) => void;
  readonly onShowVGroovePreviewChange: (enabled: boolean) => void;
  readonly onCenterPattern: () => void;
  readonly onCreateCuts: () => void;
  readonly onFitPatternToFacet: () => void;
  readonly onUndoLastCut: () => void;
}

export function GemPreviewPanel({
  project,
  selectedFacetId,
  importError,
  material,
  environmentPreset,
  cleanRender,
  gemViewMode,
  placement,
  patternPrimitiveCount,
  vGrooveSettings,
  vGrooveCutterPreset,
  vGrooveDisplayMode,
  showVGroovePreview,
  cutOperationState,
  onEnvironmentPresetChange,
  onCleanRenderChange,
  onMaterialChange,
  onGemViewModeChange,
  onPlacementChange,
  onVGrooveSettingsChange,
  onVGrooveCutterPresetChange,
  onVGrooveDisplayModeChange,
  onShowVGroovePreviewChange,
  onCenterPattern,
  onCreateCuts,
  onFitPatternToFacet,
  onUndoLastCut,
}: GemPreviewPanelProps) {
  const geometry = project.geometry;
  const selectedFacet = selectedFacetId !== undefined ? geometry?.facets.find((facet) => facet.id === selectedFacetId) : undefined;
  const grooveDimensions = calculateVGrooveDimensions(vGrooveSettings);

  return (
    <aside className="modelInfoPanel">
      <h2>Gem</h2>
      {importError ? <p className="errorText">{importError}</p> : null}
      <dl>
        <dt>File</dt>
        <dd>{project.source?.filename ?? 'Placeholder geometry'}</dd>
        <dt>Facets</dt>
        <dd>{geometry?.facets.length ?? 0}</dd>
        <dt>Selected</dt>
        <dd>{selectedFacet ? `Facet ${selectedFacet.id}` : 'None'}</dd>
      </dl>

      <h3>Material</h3>
      <label className="numberRow">
        Gem
        <select
          className="toolbarSelect"
          value={material.id}
          onChange={(event) => onMaterialChange(gemMaterialPresets[event.target.value])}
        >
          {Object.values(gemMaterialPresets).map((preset) => (
            <option key={preset.id} value={preset.id}>
              {preset.name}
            </option>
          ))}
        </select>
      </label>
      <NumberInput label="RI" value={material.refractiveIndex} min={1} step={0.001} onChange={(refractiveIndex) => onMaterialChange({ ...material, id: 'custom', name: 'Custom', refractiveIndex })} />
      <label className="numberRow">
        Color
        <input type="color" value={material.color} onChange={(event) => onMaterialChange({ ...material, id: 'custom', name: 'Custom', color: event.target.value })} />
      </label>
      <h3>Lighting</h3>
      <label className="numberRow">
        Environment
        <select className="toolbarSelect" value={environmentPreset} onChange={(event) => onEnvironmentPresetChange(event.target.value as GemEnvironmentPreset)}>
          <option value="gemStudio">Gem Studio</option>
          <option value="brightStudio">Bright Studio</option>
          <option value="darkStudio">Dark Studio</option>
          <option value="highContrast">High Contrast</option>
        </select>
      </label>

      <h3>View</h3>
      <div className="patternControls" role="tablist" aria-label="Gem view mode">
        <button
          className={gemViewMode === 'setup' ? 'toolbarButton active' : 'toolbarButton'}
          role="tab"
          aria-selected={gemViewMode === 'setup'}
          onClick={() => onGemViewModeChange('setup')}
        >
          Setup
        </button>
        <button
          className={gemViewMode === 'render' ? 'toolbarButton active' : 'toolbarButton'}
          role="tab"
          aria-selected={gemViewMode === 'render'}
          onClick={() => onGemViewModeChange('render')}
        >
          Render
        </button>
      </div>
      <label className="wireframeToggle">
        <input type="checkbox" checked={cleanRender} onChange={(event) => onCleanRenderChange(event.target.checked)} />
        Clean View
      </label>

      <h3>Pattern On Facet</h3>
      <dl>
        <dt>Pattern</dt>
        <dd>{patternPrimitiveCount > 0 ? `${patternPrimitiveCount} primitives` : 'Empty'}</dd>
        <dt>Facet</dt>
        <dd>{selectedFacet ? `Facet ${selectedFacet.id}` : 'Select a facet'}</dd>
      </dl>
      {placement ? (
        <>
          <NumberInput label="Position X" value={placement.offsetX} step={0.001} onChange={(offsetX) => onPlacementChange({ ...placement, offsetX })} />
          <NumberInput label="Position Y" value={placement.offsetY} step={0.001} onChange={(offsetY) => onPlacementChange({ ...placement, offsetY })} />
          <NumberInput label="Rotation" value={placement.rotationDeg} step={1} onChange={(rotationDeg) => onPlacementChange({ ...placement, rotationDeg })} />
          <NumberInput label="Scale" value={placement.scale} min={0.001} step={0.01} onChange={(scale) => onPlacementChange({ ...placement, scale })} />
          <div className="patternControls">
            <button className="toolbarButton" onClick={onCenterPattern}>
              Center
            </button>
            <button className="toolbarButton" onClick={onFitPatternToFacet}>
              Fit to facet
            </button>
          </div>
        </>
      ) : (
        <p>Create a 2D pattern and select a facet to place it.</p>
      )}

      <h3>Cut</h3>
      <dl>
        <dt>Operations</dt>
        <dd>{project.cutOperations.length}</dd>
      </dl>
      <label className="numberRow">
        Cutter
        <select
          className="toolbarSelect"
          value={vGrooveCutterPreset}
          onChange={(event) => {
            const preset = event.target.value as VGrooveCutterPreset;
            onVGrooveCutterPresetChange(preset);
            if (preset === '60' || preset === '90') {
              onVGrooveSettingsChange({ ...vGrooveSettings, includedAngleDeg: Number(preset) });
            }
          }}
        >
          <option value="90">90° V</option>
          <option value="60">60° V</option>
          <option value="custom">Custom</option>
        </select>
      </label>
      {vGrooveCutterPreset === 'custom' ? (
        <NumberInput
          label="Included angle"
          value={vGrooveSettings.includedAngleDeg}
          min={1}
          max={170}
          step={0.1}
          onChange={(includedAngleDeg) => onVGrooveSettingsChange({ ...vGrooveSettings, includedAngleDeg })}
        />
      ) : null}
      <NumberInput
        label="Depth"
        value={vGrooveSettings.depthMm}
        min={0.001}
        max={5}
        step={0.001}
        onChange={(depthMm) => onVGrooveSettingsChange({ ...vGrooveSettings, depthMm: clampDepth(depthMm) })}
      />
      <label className="numberRow">
        Depth
        <input
          type="range"
          min="0.001"
          max="5"
          step="0.001"
          value={vGrooveSettings.depthMm}
          onWheel={(event) => {
            event.preventDefault();
            const direction = event.deltaY < 0 ? 1 : -1;
            onVGrooveSettingsChange({ ...vGrooveSettings, depthMm: clampDepth(vGrooveSettings.depthMm + direction * 0.001) });
          }}
          onChange={(event) => onVGrooveSettingsChange({
            ...vGrooveSettings,
            depthMm: clampDepth(Number(event.target.value)),
          })}
        />
      </label>
      <dl>
        <dt>Width</dt>
        <dd>{grooveDimensions.widthMm.toFixed(3)} mm</dd>
      </dl>
      <label className="numberRow">
        Display
        <select className="toolbarSelect" value={vGrooveDisplayMode} onChange={(event) => onVGrooveDisplayModeChange(event.target.value as VGrooveDisplayMode)}>
          <option value="surfaces">Groove surfaces</option>
          <option value="centerLines">Center lines</option>
          <option value="both">Both</option>
        </select>
      </label>
      <label className="wireframeToggle">
        <input type="checkbox" checked={showVGroovePreview} onChange={(event) => onShowVGroovePreviewChange(event.target.checked)} />
        Preview cuts
      </label>
      <div className="patternControls">
        <button className="toolbarButton" disabled={!placement || patternPrimitiveCount === 0 || cutOperationState.status === 'running'} onClick={onCreateCuts}>
          {cutOperationState.status === 'running' ? 'Creating cuts...' : 'Create Cuts'}
        </button>
        <button className="toolbarButton" disabled={project.cutOperations.length === 0 || cutOperationState.status === 'running'} onClick={onUndoLastCut}>
          Undo Last Cut
        </button>
      </div>
      {cutOperationState.message ? <p aria-live="polite">{cutOperationState.message}</p> : null}
    </aside>
  );
}

function clampDepth(value: number) {
  return Math.round(Math.min(5, Math.max(0.001, value)) * 1000) / 1000;
}

function NumberInput({
  label,
  value,
  min,
  max,
  step,
  onChange,
}: {
  readonly label: string;
  readonly value: number;
  readonly min?: number;
  readonly max?: number;
  readonly step?: number;
  readonly onChange: (value: number) => void;
}) {
  return (
    <label className="numberRow">
      {label}
      <input type="number" min={min} max={max} step={step ?? 0.001} value={Number.isFinite(value) ? value : 0} onChange={(event) => onChange(Number(event.target.value))} />
    </label>
  );
}
