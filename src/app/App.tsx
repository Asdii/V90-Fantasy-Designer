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
  const [projectionMode, setProjectionMode] = useState<'perspective' | 'orthographic'>('perspective');
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
  const [objectCount, setObjectCount] = useState(0);
  const [fps, setFps] = useState(0);
  const [cutOperationState, setCutOperationState] = useState<CutOperationState>({ status: 'idle' });
  const [cutPreviewGeometry, setCutPreviewGeometry] = useState<GemGeometry | undefined>();
  const [showCutHelper, setShowCutHelper] = useState(false);
  const [showFacetMeasurement, setShowFacetMeasurement] = useState(false);
  const [patternReferenceImage, setPatternReferenceImage] = useState<PatternReferenceImage>();
  const cutOperationInProgressRef = useRef(false);
  const cutPreviewRequestRef = useRef(0);
  const latestProjectRef = useRef(project);

  latestProjectRef.current = project;

  useEffect(() => saveAppSettings(appSettings, window.localStorage), [appSettings]);

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

  const clearModel = () => {
    const placeholder = createPlaceholderGemGeometry();
    setProject((current) => ({
      ...current,
      version: 1,
      sourceGeometry: placeholder,
      geometry: placeholder,
      source: undefined,
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
      setShowFacetMeasurement(false);
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

  const handleRendererError = useCallback((message: string) => {
    console.error('[WebGi]', message);
    setImportError(message);
  }, []);

  return (
    <main className={`appShell visibility-${appSettings.highVisibility ? 'high' : 'standard'} density-${appSettings.density} textSize-${appSettings.textSize}${appSettings.reducedMotion ? ' reduceMotion' : ''}`}>
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
          onClick={() => setShowFacetMeasurement(true)}
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
            projectionMode={projectionMode}
            showFacetBoundaries={showFacetBoundaries}
            showFacetNormals={showFacetNormals}
            showLocalWorkplane={showLocalWorkplane}
            showWireframe={showWireframe}
            onClearModel={clearModel}
            onBackgroundChange={setBackground}
            onProjectionModeChange={setProjectionMode}
            onCameraViewRequest={(view) => {
              if (view === 'inspection') {
                setProjectionMode('orthographic');
              }
              setCameraViewRequest(view);
            }}
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
              fitModelRequest={fitModelRequest}
              projectionMode={projectionMode}
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
              onCameraSnapshotChange={setCameraSnapshot}
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
          <StatusBar camera={cameraSnapshot} objectCount={objectCount} fps={fps} localCursor={undefined} />
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
