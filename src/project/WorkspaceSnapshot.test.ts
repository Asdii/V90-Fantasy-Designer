import { describe, expect, it } from 'vitest';
import { defaultAppSettings } from '../app/AppSettings';
import { createPlaceholderGemGeometry } from '../geometry/createPlaceholderGemGeometry';
import { defaultVGrooveSettings } from '../grooves';
import { gemMaterialPresets } from '../materials/GemMaterial';
import { createEmptyDesignPattern } from '../patterns/model/PatternModel';
import { createWorkspaceSnapshot, parseWorkspaceSnapshot, serializeWorkspaceSnapshot } from './WorkspaceSnapshot';

describe('WorkspaceSnapshot', () => {
  it('round-trips project geometry and workspace settings', () => {
    const geometry = createPlaceholderGemGeometry();
    const designPattern = createEmptyDesignPattern();
    const snapshot = createWorkspaceSnapshot({
      project: { version: 1, sourceGeometry: geometry, geometry, cutOperations: [], patterns: {}, designPattern },
      designPattern,
      appSettings: defaultAppSettings,
      view: { designerSize: 'medium', background: 'white', environmentPreset: 'gemStudio', cleanRender: false, gemViewMode: 'setup', showWireframe: false, showFacetBoundaries: true, showFacetNormals: false, facetDebugColors: false, showLocalWorkplane: false, camera: { position: [4, 3, 4], target: [0, 0, 0] } },
      material: gemMaterialPresets.quartz,
      cut: { settings: defaultVGrooveSettings, cutterPreset: '90', displayMode: 'centerLines', preview: true, extentMode: 'patternOnly' },
    });
    const restored = parseWorkspaceSnapshot(serializeWorkspaceSnapshot(snapshot));
    expect(restored.project.geometry?.triangles).toHaveLength(12);
    expect(restored.view.background).toBe('white');
    expect(restored.cut.extentMode).toBe('patternOnly');
  });

  it('loads projects saved before cut extent modes as across-facet cuts', () => {
    const geometry = createPlaceholderGemGeometry();
    const designPattern = createEmptyDesignPattern();
    const snapshot = createWorkspaceSnapshot({
      project: { version: 1, sourceGeometry: geometry, geometry, cutOperations: [], patterns: {}, designPattern },
      designPattern,
      appSettings: defaultAppSettings,
      view: { designerSize: 'medium', background: 'white', environmentPreset: 'gemStudio', cleanRender: false, gemViewMode: 'setup', showWireframe: false, showFacetBoundaries: true, showFacetNormals: false, facetDebugColors: false, showLocalWorkplane: false, camera: { position: [4, 3, 4], target: [0, 0, 0] } },
      material: gemMaterialPresets.quartz,
      cut: { settings: defaultVGrooveSettings, cutterPreset: '90', displayMode: 'centerLines', preview: true, extentMode: 'acrossFacet' },
    });
    const legacy = JSON.parse(serializeWorkspaceSnapshot(snapshot));
    delete legacy.cut.extentMode;

    expect(parseWorkspaceSnapshot(JSON.stringify(legacy)).cut.extentMode).toBe('acrossFacet');
  });

  it('rejects unrelated JSON files', () => {
    expect(() => parseWorkspaceSnapshot('{"version":1}')).toThrow(/not a supported/);
  });
});
