import { normalizeAppSettings, type AppSettings } from '../app/AppSettings';
import type { VGrooveCutterPreset, VGrooveDisplayMode, VGrooveSettings } from '../grooves';
import type { GemMaterial } from '../materials/GemMaterial';
import type { PatternReferenceImage } from '../patterns/editor/PatternReferenceImage';
import type { DesignPattern } from '../patterns/model/PatternModel';
import type { PatternPlacement } from '../patterns/placement/PatternPlacement';
import type { BackgroundMode } from '../rendering/background';
import type { CameraSnapshot } from '../rendering/cameraViews';
import type { GemEnvironmentPreset } from '../rendering/EnvironmentPreset';
import type { GemProject } from './GemProject';

export const WORKSPACE_FILE_FORMAT = 'v90-fantasy-designer-project';
export const WORKSPACE_FILE_VERSION = 1;

export interface WorkspaceSnapshot {
  readonly format: typeof WORKSPACE_FILE_FORMAT;
  readonly version: typeof WORKSPACE_FILE_VERSION;
  readonly savedAt: string;
  readonly project: GemProject;
  readonly designPattern: DesignPattern;
  readonly patternReferenceImage?: PatternReferenceImage;
  readonly patternPlacement?: PatternPlacement;
  readonly selectedFacetId?: number;
  readonly appSettings: AppSettings;
  readonly view: {
    readonly designerSize: 'small' | 'medium' | 'large';
    readonly background: BackgroundMode;
    readonly environmentPreset: GemEnvironmentPreset;
    readonly cleanRender: boolean;
    readonly gemViewMode: 'setup' | 'render';
    readonly showWireframe: boolean;
    readonly showFacetBoundaries: boolean;
    readonly showFacetNormals: boolean;
    readonly facetDebugColors: boolean;
    readonly showLocalWorkplane: boolean;
    readonly camera: CameraSnapshot;
  };
  readonly material: GemMaterial;
  readonly cut: {
    readonly settings: VGrooveSettings;
    readonly cutterPreset: VGrooveCutterPreset;
    readonly displayMode: VGrooveDisplayMode;
    readonly preview: boolean;
  };
}

export type WorkspaceSnapshotInput = Omit<WorkspaceSnapshot, 'format' | 'version' | 'savedAt'>;

export function createWorkspaceSnapshot(input: WorkspaceSnapshotInput): WorkspaceSnapshot {
  return {
    format: WORKSPACE_FILE_FORMAT,
    version: WORKSPACE_FILE_VERSION,
    savedAt: new Date().toISOString(),
    ...input,
  };
}

export function serializeWorkspaceSnapshot(snapshot: WorkspaceSnapshot): string {
  return JSON.stringify(snapshot);
}

export function parseWorkspaceSnapshot(text: string): WorkspaceSnapshot {
  const value = JSON.parse(text) as Partial<WorkspaceSnapshot>;
  if (value.format !== WORKSPACE_FILE_FORMAT || value.version !== WORKSPACE_FILE_VERSION) {
    throw new Error('This is not a supported V90 Fantasy Designer project file.');
  }
  if (!value.project || !value.designPattern || !value.appSettings || !value.view || !value.material || !value.cut) {
    throw new Error('The project file is incomplete.');
  }
  validateGeometry(value.project.sourceGeometry, 'source geometry');
  validateGeometry(value.project.geometry, 'working geometry');
  if (!Array.isArray(value.designPattern.primitives) || !Array.isArray(value.project.cutOperations)) {
    throw new Error('The project contains invalid pattern or cut data.');
  }
  const snapshot = value as WorkspaceSnapshot;
  return {
    ...snapshot,
    appSettings: normalizeAppSettings(snapshot.appSettings),
    view: {
      ...snapshot.view,
      camera: snapshot.view.camera ?? { position: [6, 4.5, 6], target: [0, 0, 0] },
    },
  };
}

function validateGeometry(geometry: GemProject['geometry'], label: string) {
  if (!geometry || !Array.isArray(geometry.vertices) || !Array.isArray(geometry.triangles)) {
    throw new Error(`The project ${label} is missing.`);
  }
  if (geometry.triangles.length === 0 || geometry.vertices.length === 0) {
    throw new Error(`The project ${label} is empty.`);
  }
  for (const vertex of geometry.vertices) {
    if (![vertex.x, vertex.y, vertex.z].every(Number.isFinite)) {
      throw new Error(`The project ${label} contains invalid coordinates.`);
    }
  }
  for (const triangle of geometry.triangles) {
    if (![triangle.a, triangle.b, triangle.c].every((index) => Number.isInteger(index) && index >= 0 && index < geometry.vertices.length)) {
      throw new Error(`The project ${label} contains invalid triangle indices.`);
    }
  }
}
