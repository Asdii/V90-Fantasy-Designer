import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { loadAppSettings, saveAppSettings } from './AppSettings';
import { createPlaceholderGemGeometry } from '../geometry/createPlaceholderGemGeometry';
import {
  calculateMaximumMeasurementSpan,
  calculateMeasurementScaleFactor,
} from '../geometry/FacetMeasurement';
import { createFacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import type { GemGeometry } from '../geometry/GemGeometry';
import { parseStl } from '../geometry/stlParser';
import { writeBinaryStl } from '../geometry/stlWriter';
import {
  calculateVGrooveDimensions,
  createCutInstructions,
  defaultVGrooveSettings,
  rebaseCutInstruction,
  type VGrooveCutterPreset,
  type VGrooveDisplayMode,
  type VGrooveSettings,
} from '../grooves';
import { gemMaterialPresets, type GemMaterial } from '../materials/GemMaterial';
import type { GemProject } from '../project/GemProject';
import { rebuildWorkingGemGeometry } from '../project/CutOperations';
import { areCutPlaneNormalsCompatible } from '../project/CutPlaneLock';
import { scaleGemProject } from '../project/scaleGemProject';
import { loadWorkspaceCache, saveWorkspaceCache } from '../project/WorkspaceCache';
import {
  createWorkspaceSnapshot,
  parseWorkspaceSnapshot,
  serializeWorkspaceSnapshot,
  type WorkspaceSnapshot,
} from '../project/WorkspaceSnapshot';
import type { Pattern } from '../patterns/Pattern';
import { createEmptyDesignPattern, type DesignPattern } from '../patterns/model/PatternModel';
import type { PatternReferenceImage } from '../patterns/editor/PatternReferenceImage';
import {
  createDefaultPatternPlacement,
  centerPatternPlacement,
  fitPatternPlacementToFacetBounds,
  patternPlacementToWorldCutPaths,
  type PatternPlacement,
} from '../patterns/placement/PatternPlacement';
import type { BackgroundMode } from '../rendering/background';
import type { CameraSnapshot, CameraViewName } from '../rendering/cameraViews';
import { subtractVGroovesFromGemGeometry } from '../rendering/csg/VGrooveCsg';
import type { LightingPreset } from '../rendering/Scene';
import type { GemEnvironmentPreset } from '../rendering/EnvironmentPreset';
import { GemPreviewPanel } from '../ui/GemPreviewPanel';
import { CutHelperDialog } from '../ui/CutHelperDialog';
import { FacetMeasurementDialog, type FacetMeasurementResult } from '../ui/FacetMeasurementDialog';
import { AppSettingsDialog } from '../ui/AppSettingsDialog';
import { PatternDesigner } from '../ui/PatternDesigner';
import { StatusBar } from '../ui/StatusBar';
import { Toolbar } from '../ui/Toolbar';
import { Viewport } from '../ui/Viewport';

type WorkspaceArea = 'pattern' | 'gem';
type DesignerSize = 'small' | 'medium' | 'large';
type CutOperationState = { readonly status: 'idle' | 'running' | 'success' | 'error'; readonly message?: string };

export function App() {
  const [appSettings, setAppSettings] = useState(() => loadAppSettings(window.localStorage));
  const [showAppSettings, setShowAppSettings] = useState(false);
  const [activeWorkspace, setActiveWorkspace] = useState<WorkspaceArea>('pattern');
  const [designerSize, setDesignerSize] = useState<DesignerSize>('medium');
  const [background, setBackground] = useState<BackgroundMode>('white');
  const [lightingPreset] = useState<LightingPreset>('studioLight');
  const [environmentPreset, setEnvironmentPreset] = useState<GemEnvironmentPreset>('gemStudio');
  const [cleanRender, setCleanRender] = useState(false);
  const [gemMaterial, setGemMaterial] = useState<GemMaterial>(gemMaterialPresets.quartz);
  const [gemViewMode, setGemViewMode] = useState<'setup' | 'render'>('setup');
  const [cameraViewRequest, setCameraViewRequest] = useState<CameraViewName>('reset');
  const [fitModelRequest, setFitModelRequest] = useState(0);
  const [showWireframe, setShowWireframe] = useState(false);
  const [showFacetBoundaries, setShowFacetBoundaries] = useState(true);
  const [showFacetNormals, setShowFacetNormals] = useState(false);
  const [facetDebugColors, setFacetDebugColors] = useState(false);
  const [showLocalWorkplane, setShowLocalWorkplane] = useState(false);
  const [selectedFacetId, setSelectedFacetId] = useState<number | undefined>();
  const [hoveredFacetId, setHoveredFacetId] = useState<number | undefined>();
  const [designPattern, setDesignPattern] = useState<DesignPattern>(() => createEmptyDesignPattern());
  const [patternPlacement, setPatternPlacement] = useState<PatternPlacement | undefined>();
  const [vGrooveSettings, setVGrooveSettings] = useState<VGrooveSettings>(defaultVGrooveSettings);
  const [vGrooveCutterPreset, setVGrooveCutterPreset] = useState<VGrooveCutterPreset>('90');
  const [vGrooveDisplayMode, setVGrooveDisplayMode] = useState<VGrooveDisplayMode>('centerLines');
  const [showVGroovePreview, setShowVGroovePreview] = useState(true);
  const [project, setProject] = useState<GemProject>({
    version: 1,
    sourceGeometry: createPlaceholderGemGeometry(),
    geometry: createPlaceholderGemGeometry(),
    cutOperations: [],
    patterns: {},
    designPattern,
  });
  const [importError, setImportError] = useState<string | undefined>();
  const [cameraSnapshot, setCameraSnapshot] = useState<CameraSnapshot>({
    position: [0, 0, 0],
    target: [0, 0, 0],
  });
  const [cameraRestoreRequest, setCameraRestoreRequest] = useState<CameraSnapshot | undefined>();
  const cameraSnapshotRef = useRef(cameraSnapshot);
  const [objectCount, setObjectCount] = useState(0);
  const [fps, setFps] = useState(0);
  const [cutOperationState, setCutOperationState] = useState<CutOperationState>({ status: 'idle' });
  const [cutPreviewGeometry, setCutPreviewGeometry] = useState<GemGeometry | undefined>();
  const [showCutHelper, setShowCutHelper] = useState(false);
  const [showFacetMeasurement, setShowFacetMeasurement] = useState(false);
  const [facetMeasurementMessage, setFacetMeasurementMessage] = useState<string>();
  const [patternReferenceImage, setPatternReferenceImage] = useState<PatternReferenceImage>();
  const cutOperationInProgressRef = useRef(false);
  const cutPreviewRequestRef = useRef(0);
  const latestProjectRef = useRef(project);
  const [workspaceCacheReady, setWorkspaceCacheReady] = useState(false);

  latestProjectRef.current = project;

  const handleCameraSnapshotChange = useCallback((snapshot: CameraSnapshot) => {
    cameraSnapshotRef.current = snapshot;
    setCameraSnapshot(snapshot);
  }, []);

  useEffect(() => saveAppSettings(appSettings, window.localStorage), [appSettings]);

  const workspaceSnapshot = useMemo(() => createWorkspaceSnapshot({
    project,
    designPattern,
    patternReferenceImage,
    patternPlacement,
    selectedFacetId,
    appSettings,
    view: {
      designerSize,
      background,
      environmentPreset,
      cleanRender,
      gemViewMode,
      showWireframe,
      showFacetBoundaries,
      showFacetNormals,
      facetDebugColors,
      showLocalWorkplane,
      camera: cameraSnapshot,
    },
    material: gemMaterial,
    cut: {
      settings: vGrooveSettings,
      cutterPreset: vGrooveCutterPreset,
      displayMode: vGrooveDisplayMode,
      preview: showVGroovePreview,
    },
  }), [
    appSettings, background, cleanRender, designPattern, designerSize, environmentPreset,
    facetDebugColors, gemMaterial, gemViewMode, patternPlacement, patternReferenceImage,
    project, selectedFacetId, showFacetBoundaries, showFacetNormals, showLocalWorkplane,
    showVGroovePreview, showWireframe, vGrooveCutterPreset, vGrooveDisplayMode, vGrooveSettings,
  ]);

  useEffect(() => {
    let active = true;
    void loadWorkspaceCache()
      .then((snapshot) => {
        if (active && snapshot) applyWorkspaceSnapshot(snapshot);
      })
      .catch((error) => console.warn('[WorkspaceCache] Could not restore the previous session.', error))
      .finally(() => {
        if (active) setWorkspaceCacheReady(true);
      });
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (!workspaceCacheReady) return;
    const timer = window.setTimeout(() => {
      void saveWorkspaceCache(withCamera(workspaceSnapshot, cameraSnapshotRef.current))
        .catch((error) => console.warn('[WorkspaceCache] Could not save the current session.', error));
    }, 500);
    return () => window.clearTimeout(timer);
  }, [workspaceCacheReady, workspaceSnapshot]);

  const cutHelperSteps = useMemo(() => {
    const referenceOperation = project.cutOperations[0];
    if (!referenceOperation) {
      return [];
    }

    const referenceGeometry = referenceOperation.cutHelper.localGeometry;
    return project.cutOperations.flatMap((operation, operationIndex) =>
      operation.cutHelper.instructions.map((instruction) => ({
        operationId: operation.id,
        operationNumber: operationIndex + 1,
        facetId: referenceOperation.facetId,
        localGeometry: referenceGeometry,
        instruction: rebaseCutInstruction(instruction, operation.cutHelper.localGeometry, referenceGeometry),
        grooveWidthMm: operation.cutHelper.grooveWidthMm,
      })),
    );
  }, [project.cutOperations]);
  const measurementFacet = useMemo(() => {
    if (!project.geometry || selectedFacetId === undefined) {
      return undefined;
    }
    const facet = project.geometry.facets.find((candidate) => candidate.id === selectedFacetId);
    if (!facet) {
      return undefined;
    }
    const localGeometry = createFacetLocalGeometry(project.geometry, facet);
    const boundary = localGeometry.boundary.map((point) => ({ x: point.u, y: point.v }));
    const maximumSpan = calculateMaximumMeasurementSpan(boundary);
    return {
      id: facet.id,
      lengthMm: maximumSpan.lengthMm,
      guide: { boundary, maximumSpan },
    };
  }, [project.geometry, selectedFacetId]);

  const updateDesignPattern = (pattern: DesignPattern) => {
    setDesignPattern(pattern);
    setProject((current) => ({ ...current, designPattern: pattern }));
  };

  useEffect(() => {
    if (selectedFacetId === undefined || designPattern.primitives.length === 0) {
      setPatternPlacement(undefined);
      return;
    }

    setPatternPlacement((current) => {
      if (current?.facetId === selectedFacetId) {
        return current;
      }
      const facet = project.geometry?.facets.find((candidate) => candidate.id === selectedFacetId);
      if (!facet || !project.geometry) {
        return undefined;
      }
      const placement = {
        ...createDefaultPatternPlacement(selectedFacetId),
        rotationDeg: current?.rotationDeg ?? 0,
      };
      const localGeometry = createFacetLocalGeometry(project.geometry, facet);
      return fitPatternPlacementToFacetBounds(designPattern, placement, localGeometry.bounds);
    });
  }, [designPattern, project.geometry, selectedFacetId]);

  useEffect(() => {
    const request = ++cutPreviewRequestRef.current;
    if (
      !showVGroovePreview
      || cutOperationState.status === 'running'
      || !project.geometry
      || selectedFacetId === undefined
      || !patternPlacement
      || designPattern.primitives.length === 0
    ) {
      setCutPreviewGeometry(undefined);
      return;
    }

    const timer = window.setTimeout(() => {
      const geometry = project.geometry;
      const facet = geometry?.facets.find((candidate) => candidate.id === selectedFacetId);
      if (!geometry || !facet) {
        return;
      }
      const localGeometry = createFacetLocalGeometry(geometry, facet);
      const paths = patternPlacementToWorldCutPaths(designPattern, patternPlacement, localGeometry);
      void subtractVGroovesFromGemGeometry(geometry, paths, localGeometry.frame, vGrooveSettings)
        .then((result) => {
          if (cutPreviewRequestRef.current === request) {
            setCutPreviewGeometry(result.geometry);
          }
        })
        .catch((error) => {
          if (cutPreviewRequestRef.current === request) {
            console.warn('[CutPreview] Could not generate temporary boolean preview.', error);
            setCutPreviewGeometry(undefined);
          }
        });
    }, 120);

    return () => window.clearTimeout(timer);
  }, [cutOperationState.status, designPattern, patternPlacement, project.geometry, selectedFacetId, showVGroovePreview, vGrooveSettings]);

  const loadStl = async (file: File) => {
    try {
      const buffer = await file.arrayBuffer();
      const geometry = parseStl(buffer);
      setProject((current) => ({
        ...current,
        version: 1,
        source: { filename: file.name },
        sourceGeometry: geometry,
        geometry,
        cutOperations: [],
        patterns: {},
      }));
      setImportError(undefined);
      setSelectedFacetId(undefined);
      setHoveredFacetId(undefined);
      setShowCutHelper(false);
      setShowFacetMeasurement(false);
      setPatternReferenceImage(undefined);
      setFitModelRequest((value) => value + 1);
    } catch (error) {
      setImportError(error instanceof Error ? error.message : 'Could not import STL file');
    }
  };

  const newProject = () => {
    if (!window.confirm('Start a new project? The current model, patterns, measurement photo, and cuts will be cleared.')) {
      return;
    }
    const placeholder = createPlaceholderGemGeometry();
    const emptyPattern = createEmptyDesignPattern();
    setDesignPattern(emptyPattern);
    setProject({
      version: 1,
      sourceGeometry: placeholder,
      geometry: placeholder,
      cutOperations: [],
      patterns: {},
      designPattern: emptyPattern,
    });
    setImportError(undefined);
    setSelectedFacetId(undefined);
    setHoveredFacetId(undefined);
    setPatternPlacement(undefined);
    setShowCutHelper(false);
    setShowFacetMeasurement(false);
    setFacetMeasurementMessage(undefined);
    setPatternReferenceImage(undefined);
    setCutPreviewGeometry(undefined);
    setShowVGroovePreview(true);
    setFitModelRequest((value) => value + 1);
  };

  const deselectFacet = () => {
    setSelectedFacetId(undefined);
    setHoveredFacetId(undefined);
    setShowCutHelper(false);
    setShowFacetMeasurement(false);
  };

  const selectFacet = useCallback((facetId: number | undefined) => {
    if (facetId === undefined) {
      setSelectedFacetId(undefined);
      return;
    }

    const referenceOperation = project.cutOperations[0];
    const facet = project.geometry?.facets.find((candidate) => candidate.id === facetId);
    if (referenceOperation && facet && !areCutPlaneNormalsCompatible(referenceOperation.facetNormal, facet.normal)) {
      const message = `Cut plane is locked to the angle of Facet ${referenceOperation.facetId}. Select a facet with the same angle.`;
      setImportError(message);
      setCutOperationState({ status: 'error', message });
      return;
    }

    setImportError(undefined);
    setSelectedFacetId(facetId);
  }, [project.cutOperations, project.geometry]);

  const applyFacetMeasurement = ({ measuredLengthMm, referenceImage }: FacetMeasurementResult) => {
    if (!measurementFacet || measurementFacet.lengthMm <= 0 || cutOperationInProgressRef.current) {
      return;
    }
    try {
      const factor = calculateMeasurementScaleFactor(measuredLengthMm, measurementFacet.lengthMm);
      setProject((current) => scaleGemProject(current, factor));
      setPatternReferenceImage(referenceImage);
      setPatternPlacement((current) => current ? {
        ...current,
        offsetX: current.offsetX * factor,
        offsetY: current.offsetY * factor,
        scale: current.scale * factor,
      } : undefined);
      setImportError(undefined);
      setFacetMeasurementMessage(`STL scaled successfully. Maximum facet span is now ${measuredLengthMm.toFixed(3)} mm.`);
      setCutPreviewGeometry(undefined);
      setFitModelRequest((value) => value + 1);
    } catch (error) {
      setImportError(error instanceof Error ? error.message : 'Could not scale the gemstone from the measurement.');
    }
  };

  const centerPatternOnFacet = () => {
    if (!patternPlacement) {
      return;
    }
    setPatternPlacement(centerPatternPlacement(designPattern, patternPlacement));
  };

  const fitPatternToFacet = () => {
    if (!patternPlacement || selectedFacetId === undefined || !project.geometry) {
      return;
    }

    const selectedFacet = project.geometry.facets.find((facet) => facet.id === selectedFacetId);
    if (!selectedFacet) {
      return;
    }

    const localGeometry = createFacetLocalGeometry(project.geometry, selectedFacet);
    setPatternPlacement(fitPatternPlacementToFacetBounds(designPattern, patternPlacement, localGeometry.bounds));
  };

  const commitPatternForFacet = (facetId: number, pattern: Pattern) => {
    setProject((current) => ({ ...current, patterns: { ...current.patterns, [facetId]: pattern } }));
  };

  const createCuts = async () => {
    if (!project.geometry || selectedFacetId === undefined || !patternPlacement || designPattern.primitives.length === 0) {
      return;
    }
    if (cutOperationInProgressRef.current) {
      return;
    }

    const facet = project.geometry.facets.find((item) => item.id === selectedFacetId);
    if (!facet) {
      setImportError('Cannot create cuts: selected facet no longer exists.');
      return;
    }

    const referenceOperation = project.cutOperations[0];
    if (referenceOperation && !areCutPlaneNormalsCompatible(referenceOperation.facetNormal, facet.normal)) {
      const message = `Cannot create cuts: Facet ${selectedFacetId} does not match the locked angle of Facet ${referenceOperation.facetId}.`;
      setImportError(message);
      setCutOperationState({ status: 'error', message });
      return;
    }

    const baseGeometry = project.geometry;
    cutOperationInProgressRef.current = true;
    setCutOperationState({ status: 'running', message: 'Creating cuts...' });
    setImportError(undefined);
    console.debug('[CreateCuts] started');
    const startedAt = performance.now();

    try {
      await nextAnimationFrame();
      if (latestProjectRef.current.geometry !== baseGeometry) {
        throw new Error('Gem geometry changed before the cut operation started.');
      }
      const localGeometry = createFacetLocalGeometry(project.geometry, facet);
      const worldCutPaths = patternPlacementToWorldCutPaths(designPattern, patternPlacement, localGeometry);
      const cutInstructions = createCutInstructions(designPattern, patternPlacement, localGeometry, vGrooveSettings);
      console.debug('[CreateCuts] pattern paths ready', { count: worldCutPaths.length });
      const result = await subtractVGroovesFromGemGeometry(
        baseGeometry,
        worldCutPaths,
        localGeometry.frame,
        vGrooveSettings,
        (stage) => console.debug(`[CreateCuts] ${stage}`),
      );
      if (latestProjectRef.current.geometry !== baseGeometry) {
        throw new Error('Gem geometry changed while cuts were being calculated.');
      }
      const operation = {
        id: crypto.randomUUID(),
        facetId: selectedFacetId,
        patternSnapshot: designPattern,
        placement: patternPlacement,
        grooveSettings: vGrooveSettings,
        facetNormal: localGeometry.frame.normal,
        worldCutPaths,
        cutPathCount: result.cutPathCount,
        cutHelper: {
          localGeometry,
          instructions: cutInstructions,
          grooveWidthMm: calculateVGrooveDimensions(vGrooveSettings).widthMm,
        },
      };
      setProject((current) => ({
        ...current,
        geometry: result.geometry,
        cutOperations: [...current.cutOperations, operation],
      }));
      console.debug('[CreateCuts] domain geometry committed', {
        trianglesBefore: result.trianglesBefore,
        trianglesAfter: result.trianglesAfter,
      });
      setSelectedFacetId(undefined);
      setHoveredFacetId(undefined);
      setShowCutHelper(false);
      setShowFacetMeasurement(false);
      setImportError(undefined);
      setShowVGroovePreview(false);
      setCutOperationState({ status: 'success', message: 'Cuts created.' });
      console.debug('[CreateCuts] finished');
      console.debug('[CreateCuts] timing', { totalMs: performance.now() - startedAt });
    } catch (error) {
      console.error('[CreateCuts] failed', error);
      const detail = error instanceof Error ? error.message : 'Unknown cut error.';
      setImportError(`Could not create this cut. Try reducing depth or simplifying the pattern. ${detail}`);
      setCutOperationState({ status: 'error', message: 'Cut failed.' });
    } finally {
      cutOperationInProgressRef.current = false;
    }
  };

  const undoLastCut = async () => {
    const sourceGeometry = project.sourceGeometry;
    if (!sourceGeometry || project.cutOperations.length === 0 || cutOperationInProgressRef.current) {
      return;
    }

    const operations = project.cutOperations.slice(0, -1);
    const baseGeometry = project.geometry;
    const baseOperations = project.cutOperations;
    cutOperationInProgressRef.current = true;
    setCutOperationState({ status: 'running', message: 'Rebuilding cuts...' });
    try {
      await nextAnimationFrame();
      if (latestProjectRef.current.geometry !== baseGeometry || latestProjectRef.current.cutOperations !== baseOperations) {
        throw new Error('Project state changed before Undo Last Cut started.');
      }
      const rebuilt = await rebuildWorkingGemGeometry(sourceGeometry, operations);

      setProject((current) => ({ ...current, geometry: rebuilt, cutOperations: operations }));
      setSelectedFacetId(undefined);
      setHoveredFacetId(undefined);
      setShowCutHelper(false);
      setImportError(undefined);
      setCutOperationState({ status: 'success', message: 'Last cut undone.' });
    } catch (error) {
      console.error('[UndoCut] failed', error);
      setImportError(error instanceof Error ? error.message : 'Could not rebuild geometry after undo.');
      setCutOperationState({ status: 'error', message: 'Undo failed.' });
    } finally {
      cutOperationInProgressRef.current = false;
    }
  };

  useEffect(() => {
    if (activeWorkspace !== 'gem') {
      return;
    }
    const handleKeyDown = (event: KeyboardEvent) => {
      const target = event.target;
      const isEditable = target instanceof HTMLElement
        && (target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName));
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z' && !event.shiftKey && !isEditable) {
        event.preventDefault();
        void undoLastCut();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [activeWorkspace, project.cutOperations, project.geometry, project.sourceGeometry]);

  function applyWorkspaceSnapshot(snapshot: WorkspaceSnapshot) {
    const facetId = snapshot.selectedFacetId;
    const validFacetId = facetId !== undefined
      && snapshot.project.geometry?.facets.some((facet) => facet.id === facetId)
      ? facetId
      : undefined;
    setProject({ ...snapshot.project, designPattern: snapshot.designPattern });
    setDesignPattern(snapshot.designPattern);
    setPatternReferenceImage(snapshot.patternReferenceImage);
    setPatternPlacement(validFacetId !== undefined ? snapshot.patternPlacement : undefined);
    setSelectedFacetId(validFacetId);
    setHoveredFacetId(undefined);
    setAppSettings(snapshot.appSettings);
    setDesignerSize(snapshot.view.designerSize);
    setBackground(snapshot.view.background);
    setEnvironmentPreset(snapshot.view.environmentPreset);
    setCleanRender(snapshot.view.cleanRender);
    setGemViewMode(snapshot.view.gemViewMode);
    setShowWireframe(snapshot.view.showWireframe);
    setShowFacetBoundaries(snapshot.view.showFacetBoundaries);
    setShowFacetNormals(snapshot.view.showFacetNormals);
    setFacetDebugColors(snapshot.view.facetDebugColors);
    setShowLocalWorkplane(snapshot.view.showLocalWorkplane);
    if (snapshot.view.camera) {
      setCameraSnapshot(snapshot.view.camera);
      cameraSnapshotRef.current = snapshot.view.camera;
      setCameraRestoreRequest(snapshot.view.camera);
    }
    setGemMaterial(snapshot.material);
    setVGrooveSettings(snapshot.cut.settings);
    setVGrooveCutterPreset(snapshot.cut.cutterPreset);
    setVGrooveDisplayMode(snapshot.cut.displayMode);
    setShowVGroovePreview(snapshot.cut.preview);
    setShowCutHelper(false);
    setShowFacetMeasurement(false);
    setCutPreviewGeometry(undefined);
    setCutOperationState({ status: 'idle' });
    setImportError(undefined);
    setFitModelRequest((value) => value + 1);
  }

  const saveProjectFile = () => {
    const filename = project.source?.filename
      ? `${stripExtension(project.source.filename)}.v90project`
      : 'v90-fantasy-project.v90project';
    downloadBlob(new Blob([serializeWorkspaceSnapshot(withCamera(workspaceSnapshot, cameraSnapshotRef.current))], { type: 'application/json' }), filename);
  };

  const loadProjectFile = async (file: File) => {
    try {
      const snapshot = parseWorkspaceSnapshot(await file.text());
      applyWorkspaceSnapshot(snapshot);
      await saveWorkspaceCache(snapshot);
    } catch (error) {
      setImportError(error instanceof Error ? error.message : 'Could not load the project file.');
    }
  };

  const exportWorkingStl = () => {
    if (!project.geometry) return;
    const filename = project.source?.filename
      ? `${stripExtension(project.source.filename)}-cut.stl`
      : 'v90-fantasy-model.stl';
    downloadBlob(new Blob([writeBinaryStl(project.geometry)], { type: 'model/stl' }), filename);
  };

  const handleRendererError = useCallback((message: string) => {
    console.error('[WebGi]', message);
    setImportError(message);
  }, []);

  return (
    <main className={`appShell theme-${appSettings.theme} visibility-${appSettings.visibility} density-${appSettings.density} textSize-${appSettings.textSize} gridContrast-${appSettings.gridContrast}${appSettings.reducedMotion ? ' reduceMotion' : ''}`}>
      <header className="appTabs">
        <strong className="workspaceTitle">V90 Fantasy Designer</strong>
        <div className="designerSizeControls" role="group" aria-label="Pattern Designer size">
          <span>Designer</span>
          {(['small', 'medium', 'large'] as const).map((size) => (
            <button key={size} className={designerSize === size ? 'toolbarButton active' : 'toolbarButton'} onClick={() => setDesignerSize(size)}>
              {size[0].toUpperCase()}
            </button>
          ))}
        </div>
        <button className="toolbarButton" disabled={cutHelperSteps.length === 0} onClick={() => setShowCutHelper(true)}>
          Cut Helper
        </button>
        <button
          className="toolbarButton"
          disabled={!measurementFacet || cutOperationState.status === 'running'}
            onClick={() => {
              setFacetMeasurementMessage(undefined);
              setShowFacetMeasurement(true);
            }}
        >
          Measure Facet
        </button>
        <button className="toolbarButton" onClick={() => setShowAppSettings(true)}>
          Settings
        </button>
      </header>

      <section className={`combinedWorkspace designerSize-${designerSize}`}>
        <section
          className="designerPane"
          aria-label="Pattern Designer"
          onFocusCapture={() => setActiveWorkspace('pattern')}
          onPointerDownCapture={() => setActiveWorkspace('pattern')}
        >
          <PatternDesigner
            pattern={designPattern}
            onPatternChange={updateDesignPattern}
            referenceImage={patternReferenceImage}
            onReferenceImageChange={setPatternReferenceImage}
            keyboardActive={activeWorkspace === 'pattern'}
          />
        </section>
        <section
          className="gemPane"
          aria-label="Gem Preview"
          onFocusCapture={() => setActiveWorkspace('gem')}
          onPointerDownCapture={() => setActiveWorkspace('gem')}
        >
          <Toolbar
            background={background}
            facetDebugColors={facetDebugColors}
            canExportModel={Boolean(project.geometry)}
            showFacetBoundaries={showFacetBoundaries}
            showFacetNormals={showFacetNormals}
            showLocalWorkplane={showLocalWorkplane}
            showWireframe={showWireframe}
            onClearModel={newProject}
            onExportStl={exportWorkingStl}
            onLoadProject={loadProjectFile}
            onSaveProject={saveProjectFile}
            onBackgroundChange={setBackground}
            onCameraViewRequest={setCameraViewRequest}
            onFitModel={() => setFitModelRequest((value) => value + 1)}
            onLoadStl={loadStl}
            onFacetBoundariesChange={setShowFacetBoundaries}
            onFacetDebugColorsChange={setFacetDebugColors}
            onFacetNormalsChange={setShowFacetNormals}
            onLocalWorkplaneChange={setShowLocalWorkplane}
            onWireframeChange={setShowWireframe}
          />
          <section className="workspace">
            <Viewport
              background={background}
              cutPreviewGeometry={showVGroovePreview ? cutPreviewGeometry : undefined}
              cameraViewRequest={cameraViewRequest}
              cameraRestoreRequest={cameraRestoreRequest}
              fitModelRequest={fitModelRequest}
              projectionMode="perspective"
              project={project}
              designPattern={designPattern}
              gemMaterial={gemMaterial}
              renderMode={gemViewMode}
              lightingPreset={lightingPreset}
              environmentPreset={environmentPreset}
              cleanRender={cleanRender || gemViewMode === 'render'}
              patternPlacement={patternPlacement}
              vGrooveSettings={vGrooveSettings}
              vGrooveDisplayMode={vGrooveDisplayMode}
              showVGroovePreview={showVGroovePreview && cutOperationState.status !== 'running'}
              facetDebugColors={facetDebugColors}
              hoveredFacetId={hoveredFacetId}
              selectedFacetId={selectedFacetId}
              showFacetBoundaries={showFacetBoundaries}
              showFacetNormals={showFacetNormals}
              showLocalWorkplane={showLocalWorkplane}
              showWireframe={showWireframe}
              activeTool="select"
              gridSnap="off"
              selectedSegmentId={undefined}
              snapEnabled={false}
              radialSymmetryEnabled={false}
              radialSymmetryOrder={1}
              onCameraSnapshotChange={handleCameraSnapshotChange}
              onDeselectFacet={deselectFacet}
              onPatternCommit={commitPatternForFacet}
              onHoveredFacetChange={setHoveredFacetId}
              onLocalCursorChange={() => undefined}
              onObjectCountChange={setObjectCount}
              onFpsChange={setFps}
              onSelectedFacetChange={selectFacet}
              onSelectedSegmentChange={() => undefined}
              onRendererError={handleRendererError}
            />
            <aside className="sidePanel">
              <GemPreviewPanel
                project={project}
                selectedFacetId={selectedFacetId}
                importError={importError}
                material={gemMaterial}
                environmentPreset={environmentPreset}
                cleanRender={cleanRender}
                gemViewMode={gemViewMode}
                placement={patternPlacement}
                patternPrimitiveCount={designPattern.primitives.length}
                vGrooveSettings={vGrooveSettings}
                vGrooveCutterPreset={vGrooveCutterPreset}
                vGrooveDisplayMode={vGrooveDisplayMode}
                showVGroovePreview={showVGroovePreview}
                cutOperationState={cutOperationState}
                cutPlaneReferenceFacetId={project.cutOperations[0]?.facetId}
                onEnvironmentPresetChange={setEnvironmentPreset}
                onCleanRenderChange={setCleanRender}
                onMaterialChange={setGemMaterial}
                onGemViewModeChange={setGemViewMode}
                onPlacementChange={setPatternPlacement}
                onVGrooveSettingsChange={setVGrooveSettings}
                onVGrooveCutterPresetChange={setVGrooveCutterPreset}
                onVGrooveDisplayModeChange={setVGrooveDisplayMode}
                onShowVGroovePreviewChange={setShowVGroovePreview}
                onCenterPattern={centerPatternOnFacet}
                onCreateCuts={createCuts}
                onFitPatternToFacet={fitPatternToFacet}
                onUndoLastCut={undoLastCut}
              />
            </aside>
          </section>
          {appSettings.showStatusBar ? (
            <StatusBar camera={cameraSnapshot} objectCount={objectCount} fps={fps} localCursor={undefined} />
          ) : null}
        </section>
      </section>
      {showCutHelper && cutHelperSteps.length > 0 ? (
        <CutHelperDialog
          steps={cutHelperSteps}
          onClose={() => setShowCutHelper(false)}
        />
      ) : null}
      {showFacetMeasurement && measurementFacet ? (
        <FacetMeasurementDialog
          facetId={measurementFacet.id}
          modelFacetLengthMm={measurementFacet.lengthMm}
          facetGuide={measurementFacet.guide}
          statusMessage={facetMeasurementMessage}
          onApply={applyFacetMeasurement}
          onClose={() => setShowFacetMeasurement(false)}
        />
      ) : null}
      {showAppSettings ? (
        <AppSettingsDialog settings={appSettings} onChange={setAppSettings} onClose={() => setShowAppSettings(false)} />
      ) : null}
    </main>
  );
}

function nextAnimationFrame() {
  return new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
}

function stripExtension(filename: string) {
  return filename.replace(/\.[^.]+$/, '');
}

function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  window.setTimeout(() => URL.revokeObjectURL(url), 0);
}

function withCamera(snapshot: WorkspaceSnapshot, camera: CameraSnapshot): WorkspaceSnapshot {
  return { ...snapshot, view: { ...snapshot.view, camera } };
}
