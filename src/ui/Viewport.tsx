import { useEffect, useMemo, useRef, useState } from 'react';
import * as THREE from 'three';
import type { BoundingBox, GemGeometry } from '../geometry/GemGeometry';
import { createFacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import { isPointInsideFacetLocal } from '../geometry/PointInPolygon';
import { generateVGroovePreviewGeometry, type VGrooveDisplayMode, type VGrooveSettings } from '../grooves';
import type { GemProject } from '../project/GemProject';
import type { GridSnapStep, LineSegment2D, Pattern, PatternTool, Vec2 } from '../patterns/Pattern';
import type { GemMaterial } from '../materials/GemMaterial';
import type { DesignPattern } from '../patterns/model/PatternModel';
import { patternPlacementToWorldCutPaths, type PatternPlacement } from '../patterns/placement/PatternPlacement';
import { createEmptyPattern, createSegment } from '../patterns/Pattern';
import {
  circularArraySegments,
  createCircleSegments,
  createPolylineSegments,
  createRectangleSegments,
  inverseTransformPoint,
  removeSegment,
  replaceSegment,
  transformSegment,
  transformPoint,
} from '../patterns/PatternGeometry';
import { CLICK_DRAG_THRESHOLD_PX, FacetSelectionService, buildTriangleToFacetMap } from '../interaction/FacetSelectionService';
import { pickLocalPointOnFacetPlane } from '../interaction/PatternPlanePicker';
import type { PatternEndpointHandle, PatternHit } from '../interaction/PatternSelection';
import { SNAP_DISTANCE_PX, createPatternEndpointCandidates, snapPoint, type SnapCandidate } from '../interaction/SnapService';
import type { AppCamera } from '../rendering/CameraSystem';
import { GemRenderer } from '../rendering/GemRenderer';
import { PatternRenderer } from '../rendering/PatternRenderer';
import { PlacedPatternRenderer } from '../rendering/PlacedPatternRenderer';
import { applyStudioLighting, type LightingPreset } from '../rendering/Scene';
import { VGroovePreviewRenderer } from '../rendering/VGroovePreviewRenderer';
import { createRenderableGeometry } from '../rendering/createRenderableGeometry';
import { backgroundColors, type BackgroundMode } from '../rendering/background';
import type { CameraSnapshot, CameraViewName } from '../rendering/cameraViews';
import type { GemEnvironmentPreset } from '../rendering/EnvironmentPreset';
import {
  createIJewelBaseMaterial,
  createIJewelGeometry,
  createIJewelMesh,
  createIJewelSetupMaterial,
  IJewelGemRenderer,
} from '../rendering/ijewel';

interface ViewportProps {
  readonly background: BackgroundMode;
  readonly cameraViewRequest: CameraViewName;
  readonly cameraRestoreRequest?: CameraSnapshot;
  readonly fitModelRequest: number;
  readonly facetDebugColors: boolean;
  readonly projectionMode: 'perspective' | 'orthographic';
  readonly renderMode: 'setup' | 'render';
  readonly project: GemProject;
  readonly cutPreviewGeometry?: GemGeometry;
  readonly designPattern?: DesignPattern;
  readonly generatorPreview?: Pattern;
  readonly gemMaterial?: GemMaterial;
  readonly lightingPreset: LightingPreset;
  readonly environmentPreset: GemEnvironmentPreset;
  readonly cleanRender: boolean;
  readonly patternPlacement?: PatternPlacement;
  readonly vGrooveSettings?: VGrooveSettings;
  readonly vGrooveDisplayMode: VGrooveDisplayMode;
  readonly showVGroovePreview: boolean;
  readonly showFacetBoundaries: boolean;
  readonly showFacetNormals: boolean;
  readonly showLocalWorkplane: boolean;
  readonly showWireframe: boolean;
  readonly hoveredFacetId?: number;
  readonly selectedFacetId?: number;
  readonly activeTool: PatternTool;
  readonly gridSnap: GridSnapStep;
  readonly selectedSegmentId?: string;
  readonly snapEnabled: boolean;
  readonly radialSymmetryEnabled: boolean;
  readonly radialSymmetryOrder: number;
  readonly onCameraSnapshotChange: (snapshot: CameraSnapshot) => void;
  readonly onDeselectFacet: () => void;
  readonly onPatternCommit: (facetId: number, pattern: Pattern) => void;
  readonly onObjectCountChange: (count: number) => void;
  readonly onFpsChange: (fps: number) => void;
  readonly onHoveredFacetChange: (facetId: number | undefined) => void;
  readonly onLocalCursorChange: (point: Vec2 | undefined) => void;
  readonly onSelectedFacetChange: (facetId: number | undefined) => void;
  readonly onSelectedSegmentChange: (segmentId: string | undefined) => void;
  readonly onRendererError: (message: string) => void;
}

const viewDirections: Record<CameraViewName, THREE.Vector3> = {
  reset: new THREE.Vector3(1, 0.75, 1),
  top: new THREE.Vector3(0, 1, 0),
  bottom: new THREE.Vector3(0, -1, 0),
  front: new THREE.Vector3(0, 0, 1),
  back: new THREE.Vector3(0, 0, -1),
  left: new THREE.Vector3(-1, 0, 0),
  right: new THREE.Vector3(1, 0, 0),
};

interface ViewportControls {
  readonly target: THREE.Vector3;
  update(): void;
}

export function Viewport({
  background,
  cameraViewRequest,
  cameraRestoreRequest,
  fitModelRequest,
  facetDebugColors,
  projectionMode,
  renderMode,
  project,
  cutPreviewGeometry,
  designPattern,
  generatorPreview,
  gemMaterial,
  lightingPreset,
  environmentPreset,
  cleanRender,
  patternPlacement,
  vGrooveSettings,
  vGrooveDisplayMode,
  showVGroovePreview,
  showFacetBoundaries,
  showFacetNormals,
  showLocalWorkplane,
  showWireframe,
  hoveredFacetId,
  selectedFacetId,
  activeTool,
  gridSnap,
  selectedSegmentId,
  snapEnabled,
  radialSymmetryEnabled,
  radialSymmetryOrder,
  onCameraSnapshotChange,
  onDeselectFacet,
  onPatternCommit,
  onObjectCountChange,
  onFpsChange,
  onHoveredFacetChange,
  onLocalCursorChange,
  onSelectedFacetChange,
  onSelectedSegmentChange,
  onRendererError,
}: ViewportProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<AppCamera | null>(null);
  const controlsRef = useRef<ViewportControls | null>(null);
  const gemRendererRef = useRef<GemRenderer | null>(null);
  const patternRendererRef = useRef<PatternRenderer | null>(null);
  const placedPatternRendererRef = useRef<PlacedPatternRenderer | null>(null);
  const vGroovePreviewRendererRef = useRef<VGroovePreviewRenderer | null>(null);
  const webGiRendererRef = useRef<IJewelGemRenderer | null>(null);
  const selectionServiceRef = useRef<FacetSelectionService | null>(null);
  const cleanRenderRef = useRef(cleanRender);
  const gemCacheKeyRef = useRef('working-gem-initial');
  const gemRenderRevisionRef = useRef(0);
  const renderModeRef = useRef(renderMode);
  const callbacksRef = useRef({
    onCameraSnapshotChange,
    onFpsChange,
    onObjectCountChange,
    onRendererError,
  });
  const pointerDownRef = useRef<{ x: number; y: number } | null>(null);
  const dragEndpointRef = useRef<{
    segmentId: string;
    endpoint: PatternEndpointHandle;
    originalPattern: Pattern;
  } | null>(null);
  const [pendingPoints, setPendingPoints] = useState<Vec2[]>([]);
  const [previewPoint, setPreviewPoint] = useState<Vec2 | undefined>();
  const [dragPreviewPattern, setDragPreviewPattern] = useState<Pattern | undefined>();
  const [viewerReady, setViewerReady] = useState(false);

  cleanRenderRef.current = cleanRender;
  renderModeRef.current = renderMode;
  callbacksRef.current = { onCameraSnapshotChange, onFpsChange, onObjectCountChange, onRendererError };

  useEffect(() => {
    const camera = cameraRef.current;
    const controls = controlsRef.current;
    if (!camera || !controls || !cameraRestoreRequest) {
      return;
    }
    camera.position.fromArray(cameraRestoreRequest.position);
    controls.target.fromArray(cameraRestoreRequest.target);
    camera.lookAt(controls.target);
    controls.update();
  }, [cameraRestoreRequest, viewerReady]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const host = canvas?.parentElement;
    if (!canvas || !host) {
      return;
    }

    const webGiRenderer = new IJewelGemRenderer(canvas, {
      projectionMode,
      environment: environmentPreset,
      background: backgroundColors[background],
    });
    const scene = webGiRenderer.scene as unknown as THREE.Scene;
    const camera = webGiRenderer.camera as unknown as AppCamera;
    const controls = webGiRenderer.controls as unknown as ViewportControls | undefined;
    if (!controls?.target) {
      webGiRenderer.dispose();
      throw new Error('Threepipe orbit controls were not initialized.');
    }
    applyStudioLighting(scene, lightingPreset);

    const gemRenderer = new GemRenderer(scene, {
      createGeometry: (geometry, debugColors) => (
        debugColors
          ? createRenderableGeometry(geometry, { facetColors: true })
          : createIJewelGeometry(geometry) as unknown as THREE.BufferGeometry
      ),
      createMaterial: (material, debugColors) => (
        renderModeRef.current === 'setup'
          ? createIJewelSetupMaterial(debugColors)
          : createIJewelBaseMaterial(material, debugColors)
      ) as unknown as THREE.Material,
      createMesh: (geometry, material) => createIJewelMesh(
        geometry as unknown as import('webgi').BufferGeometry,
        material as unknown as import('webgi').Material,
      ) as unknown as THREE.Mesh,
      onMeshCreated: (mesh, material) => {
        if (renderModeRef.current === 'setup') {
          webGiRenderer.invalidate();
          return;
        }
        void webGiRenderer
          .prepareGem(mesh as unknown as import('webgi').Mesh, material, gemCacheKeyRef.current)
          .catch((error) => callbacksRef.current.onRendererError(formatError(error, 'Could not prepare gemstone material.')));
      },
    });
    const patternRenderer = new PatternRenderer(scene);
    const placedPatternRenderer = new PlacedPatternRenderer(scene);
    const vGroovePreviewRenderer = new VGroovePreviewRenderer(scene);
    sceneRef.current = scene;
    cameraRef.current = camera;
    controlsRef.current = controls;
    gemRendererRef.current = gemRenderer;
    patternRendererRef.current = patternRenderer;
    placedPatternRendererRef.current = placedPatternRenderer;
    vGroovePreviewRendererRef.current = vGroovePreviewRenderer;
    webGiRendererRef.current = webGiRenderer;
    setViewerReady(true);

    let animationFrame = 0;
    let frames = 0;
    let lastFpsUpdate = performance.now();
    const animate = (now: number) => {
      applyCleanRenderVisibility(scene, cleanRenderRef.current);
      frames += 1;

      if (now - lastFpsUpdate >= 500) {
        callbacksRef.current.onFpsChange(Math.round((frames * 1000) / (now - lastFpsUpdate)));
        frames = 0;
        lastFpsUpdate = now;
        callbacksRef.current.onObjectCountChange(scene.children.length);
        callbacksRef.current.onCameraSnapshotChange(snapshotCamera(camera, controls.target));
      }

      animationFrame = requestAnimationFrame(animate);
    };

    animationFrame = requestAnimationFrame(animate);

    return () => {
      cancelAnimationFrame(animationFrame);
      gemRenderer.clear();
      patternRenderer.dispose();
      placedPatternRenderer.dispose();
      vGroovePreviewRenderer.dispose();
      webGiRendererRef.current = null;
      setViewerReady(false);
      webGiRenderer.dispose();
    };
  }, []);

  useEffect(() => {
    const renderer = webGiRendererRef.current;
    if (!renderer) {
      return;
    }
    try {
      renderer.setProjectionMode(projectionMode);
      const controls = renderer.controls as unknown as ViewportControls | undefined;
      if (!controls?.target) {
        throw new Error('Threepipe orbit controls are unavailable for the selected projection.');
      }
      cameraRef.current = renderer.camera as unknown as AppCamera;
      controlsRef.current = controls;
    } catch (error) {
      callbacksRef.current.onRendererError(formatError(error, 'Could not change camera projection.'));
    }
  }, [projectionMode]);

  useEffect(() => {
    const renderer = gemRendererRef.current;
    if (!renderer) {
      return;
    }
    const startedAt = performance.now();
    const renderGeometry = cutPreviewGeometry ?? project.geometry;
    gemRenderRevisionRef.current += 1;
    gemCacheKeyRef.current = `${cutPreviewGeometry ? 'cut-preview' : 'working-gem'}-${gemRenderRevisionRef.current}`;
    console.debug('[WebGiMeshSwap] update started');
    try {
      renderer.setGeometry(renderGeometry, {
        showWireframe: cleanRender ? false : showWireframe,
        showFacetBoundaries: cleanRender ? false : showFacetBoundaries,
        showFacetNormals: cleanRender ? false : showFacetNormals,
        facetDebugColors: cleanRender ? false : facetDebugColors,
        material: gemMaterial,
      });
      selectionServiceRef.current = project.geometry
        ? new FacetSelectionService(buildTriangleToFacetMap(project.geometry), project.geometry)
        : null;
      webGiRendererRef.current?.invalidate();
      console.debug('[WebGiMeshSwap] synchronous swap completed', { totalMs: performance.now() - startedAt });
    } catch (error) {
      callbacksRef.current.onRendererError(formatError(error, 'Could not replace the WebGi gemstone mesh.'));
    }
  }, [cleanRender, cutPreviewGeometry, facetDebugColors, gemMaterial, project.geometry, projectionMode, renderMode, showFacetBoundaries, showFacetNormals, showWireframe]);

  useEffect(() => {
    webGiRendererRef.current?.setBackground(backgroundColors[background]);
  }, [background, projectionMode]);

  useEffect(() => {
    const renderer = webGiRendererRef.current;
    if (!renderer) {
      return;
    }
    void renderer.setEnvironment(environmentPreset).catch((error) => {
      callbacksRef.current.onRendererError(formatError(error, 'Could not update the WebGi environment.'));
    });
  }, [environmentPreset, projectionMode]);

  useEffect(() => {
    const scene = sceneRef.current;
    if (scene) {
      applyStudioLighting(scene, lightingPreset);
      webGiRendererRef.current?.invalidate();
    }
  }, [lightingPreset, projectionMode]);

  useEffect(() => {
    const geometry = project.geometry;
    const renderer = placedPatternRendererRef.current;
    const facet = selectedFacetId !== undefined ? geometry?.facets.find((item) => item.id === selectedFacetId) : undefined;
    const localGeometry = geometry && facet ? createFacetLocalGeometry(geometry, facet) : undefined;

    renderer?.render(geometry, localGeometry, cleanRender || cutPreviewGeometry ? undefined : designPattern, patternPlacement, true);
  }, [cleanRender, cutPreviewGeometry, designPattern, patternPlacement, project.geometry, selectedFacetId]);

  useEffect(() => {
    const geometry = project.geometry;
    const renderer = vGroovePreviewRendererRef.current;
    const facet = selectedFacetId !== undefined ? geometry?.facets.find((item) => item.id === selectedFacetId) : undefined;
    const localGeometry = geometry && facet ? createFacetLocalGeometry(geometry, facet) : undefined;

    if (!renderer || !geometry || !localGeometry || !designPattern || !patternPlacement || !vGrooveSettings) {
      renderer?.render(undefined, vGrooveDisplayMode, false, false);
      return;
    }

    const worldCutPaths = patternPlacementToWorldCutPaths(designPattern, patternPlacement, localGeometry);
    const grooveGeometry = generateVGroovePreviewGeometry(worldCutPaths, localGeometry.frame, vGrooveSettings);
    const showCenterLines = vGrooveDisplayMode === 'centerLines' || vGrooveDisplayMode === 'both';
    renderer.render(
      grooveGeometry,
      'centerLines',
      cleanRender ? false : showVGroovePreview && showCenterLines,
      false,
    );
  }, [
    cleanRender,
    designPattern,
    patternPlacement,
    project.geometry,
    selectedFacetId,
    showVGroovePreview,
    vGrooveDisplayMode,
    vGrooveSettings,
  ]);

  useEffect(() => {
    const geometry = project.geometry;
    const renderer = patternRendererRef.current;
    const facet = selectedFacetId !== undefined ? geometry?.facets.find((item) => item.id === selectedFacetId) : undefined;
    const localGeometry = geometry && facet ? createFacetLocalGeometry(geometry, facet) : undefined;
    const pattern = dragPreviewPattern ?? (selectedFacetId !== undefined ? project.patterns[selectedFacetId] : undefined);

    renderer?.render(geometry, facet, localGeometry, cleanRender ? undefined : pattern, {
      previewSegments: cleanRender ? [] : [
        ...(generatorPreview ? generatorPreview.segments.map((segment) => transformSegment(segment, generatorPreview.transform)) : []),
        ...createSymmetricSegments(
          createPreviewSegments(activeTool, pendingPoints, previewPoint),
          radialSymmetryEnabled,
          radialSymmetryOrder,
        ),
      ],
      selectedSegmentId,
      showOutsideFacet: true,
    });
  }, [
    activeTool,
    cleanRender,
    dragPreviewPattern,
    pendingPoints,
    previewPoint,
    generatorPreview,
    project.geometry,
    project.patterns,
    radialSymmetryEnabled,
    radialSymmetryOrder,
    selectedFacetId,
    selectedSegmentId,
  ]);

  useEffect(() => {
    const geometry = project.geometry;
    const gemRenderer = gemRendererRef.current;
    if (!geometry || !gemRenderer) {
      return;
    }

    gemRenderer.setInteractionVisuals(
      geometry,
      cleanRender ? undefined : hoveredFacetId,
      cleanRender ? undefined : selectedFacetId,
      cleanRender ? false : showLocalWorkplane,
    );
  }, [cleanRender, hoveredFacetId, project.geometry, selectedFacetId, showLocalWorkplane]);

  useEffect(() => {
    const camera = cameraRef.current;
    const controls = controlsRef.current;
    if (!camera || !controls) {
      return;
    }

    const boundingBox = project.geometry?.boundingBox;
    const center = boundingBox
      ? new THREE.Vector3(boundingBox.center.x, boundingBox.center.y, boundingBox.center.z)
      : new THREE.Vector3(0, 0, 0);
    const radius = boundingBox
      ? Math.max(new THREE.Vector3(boundingBox.size.x, boundingBox.size.y, boundingBox.size.z).length() / 2, 1)
      : 2;
    const direction = viewDirections[cameraViewRequest].clone().normalize();
    controls.target.copy(center);
    camera.position.copy(center.clone().add(direction.multiplyScalar(radius * 4)));
    camera.up.set(0, 1, 0);
    if (cameraViewRequest === 'top' || cameraViewRequest === 'bottom') {
      camera.up.set(0, 0, cameraViewRequest === 'top' ? -1 : 1);
    }
    camera.lookAt(controls.target);
    controls.update();
    onCameraSnapshotChange(snapshotCamera(camera, controls.target));
  }, [cameraViewRequest, onCameraSnapshotChange]);

  useEffect(() => {
    const camera = cameraRef.current;
    const controls = controlsRef.current;
    const geometry = project.geometry;
    if (!camera || !controls || !geometry) {
      return;
    }

    fitCameraToBoundingBox(camera, controls, geometry.boundingBox);
    onCameraSnapshotChange(snapshotCamera(camera, controls.target));
  }, [fitModelRequest, onCameraSnapshotChange, projectionMode]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        if (pendingPoints.length > 0) {
          setPendingPoints([]);
          setPreviewPoint(undefined);
          return;
        }
        onDeselectFacet();
      }

      if (event.key === 'Enter' && (activeTool === 'polygon' || activeTool === 'polyline')) {
        commitPendingPath(activeTool === 'polygon');
      }

      if ((event.key === 'Delete' || event.key === 'Backspace') && selectedFacetId !== undefined && selectedSegmentId) {
        const pattern = project.patterns[selectedFacetId];
        if (pattern) {
          onPatternCommit(selectedFacetId, removeSegment(pattern, selectedSegmentId));
          onSelectedSegmentChange(undefined);
          setDragPreviewPattern(undefined);
        }
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [activeTool, onDeselectFacet, onPatternCommit, onSelectedSegmentChange, pendingPoints, project.patterns, selectedFacetId, selectedSegmentId]);

  const pickFacet = (clientX: number, clientY: number) => {
    const canvas = canvasRef.current;
    const camera = cameraRef.current;
    const gemRenderer = gemRendererRef.current;
    const selectionService = selectionServiceRef.current;

    if (!canvas || !camera || !gemRenderer || !selectionService) {
      return undefined;
    }

    return selectionService.pickFacet(clientX, clientY, canvas, camera, gemRenderer.getSelectableMesh());
  };

  const handlePointerDown = (event: React.PointerEvent<HTMLCanvasElement>) => {
    if (event.button !== 0) {
      return;
    }

    pointerDownRef.current = { x: event.clientX, y: event.clientY };

    if (activeTool === 'select') {
      const localPoint = getSnappedLocalPoint(event.clientX, event.clientY);
      const pattern = selectedFacetId !== undefined ? project.patterns[selectedFacetId] : undefined;
      const hit = pattern ? hitTestPatternScreen(pattern, event.clientX, event.clientY) : undefined;
      if (hit?.endpoint && pattern) {
        dragEndpointRef.current = {
          segmentId: hit.segmentId,
          endpoint: hit.endpoint,
          originalPattern: pattern,
        };
      }
    }
  };

  const handlePointerMove = (event: React.PointerEvent<HTMLCanvasElement>) => {
    const localPoint = getSnappedLocalPoint(event.clientX, event.clientY);
    onLocalCursorChange(localPoint);

    if (dragEndpointRef.current && selectedFacetId !== undefined && localPoint) {
      const pattern = project.patterns[selectedFacetId];
      const segment = pattern?.segments.find((item) => item.id === dragEndpointRef.current?.segmentId);
      if (pattern && segment) {
        const basePoint = inverseTransformPoint(localPoint, pattern.transform);
        const nextSegment =
          dragEndpointRef.current.endpoint === 'start'
            ? { ...segment, start: basePoint }
            : { ...segment, end: basePoint };
        setDragPreviewPattern(replaceSegment(pattern, nextSegment));
      }
      return;
    }

    if (activeTool !== 'select') {
      setPreviewPoint(localPoint);
    }

    if (pointerDownRef.current) {
      const dx = event.clientX - pointerDownRef.current.x;
      const dy = event.clientY - pointerDownRef.current.y;
      if (Math.hypot(dx, dy) > CLICK_DRAG_THRESHOLD_PX) {
        onHoveredFacetChange(undefined);
      }
      return;
    }

    onHoveredFacetChange(pickFacet(event.clientX, event.clientY));
  };

  const handlePointerLeave = () => {
    pointerDownRef.current = null;
    dragEndpointRef.current = null;
    setDragPreviewPattern(undefined);
    onHoveredFacetChange(undefined);
    onLocalCursorChange(undefined);
  };

  const handlePointerUp = (event: React.PointerEvent<HTMLCanvasElement>) => {
    const pointerDown = pointerDownRef.current;
    pointerDownRef.current = null;

    if (dragEndpointRef.current && selectedFacetId !== undefined) {
      const pattern = dragPreviewPattern;
      if (pattern) {
        onPatternCommit(selectedFacetId, pattern);
      }
      dragEndpointRef.current = null;
      setDragPreviewPattern(undefined);
      return;
    }

    if (!pointerDown || event.button !== 0) {
      return;
    }

    const moved = Math.hypot(event.clientX - pointerDown.x, event.clientY - pointerDown.y);
    if (moved > CLICK_DRAG_THRESHOLD_PX) {
      dragEndpointRef.current = null;
      return;
    }

    if (activeTool !== 'select') {
      const localPoint = getSnappedLocalPoint(event.clientX, event.clientY);
      if (localPoint) {
        handleDrawingClick(localPoint);
      }
      return;
    }

    const localPoint = getSnappedLocalPoint(event.clientX, event.clientY);
    const pattern = selectedFacetId !== undefined ? project.patterns[selectedFacetId] : undefined;
    const patternHit = pattern ? hitTestPatternScreen(pattern, event.clientX, event.clientY) : undefined;
    if (patternHit) {
      onSelectedSegmentChange(patternHit.segmentId);
      dragEndpointRef.current = null;
      return;
    }

    const facetId = pickFacet(event.clientX, event.clientY);
    onSelectedFacetChange(facetId);
    onSelectedSegmentChange(undefined);
    onHoveredFacetChange(facetId);
    setPendingPoints([]);
    setPreviewPoint(undefined);
  };

  const handleDoubleClick = () => {
    if (activeTool === 'polygon') {
      commitPendingPath(true);
    } else if (activeTool === 'polyline') {
      commitPendingPath(false);
    }
  };

  const handleContextMenu = (event: React.MouseEvent<HTMLCanvasElement>) => {
    if (pendingPoints.length > 0) {
      event.preventDefault();
      setPendingPoints([]);
      setPreviewPoint(undefined);
    }
  };

  return (
    <section className="viewportShell" aria-label="3D viewport" data-tour="gem-viewport">
      <canvas
        ref={canvasRef}
        className="viewportCanvas"
        onPointerDown={handlePointerDown}
        onPointerLeave={handlePointerLeave}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onDoubleClick={handleDoubleClick}
        onContextMenu={handleContextMenu}
      />
      {!cleanRender && project.geometry ? <ModelScalePreview geometry={project.geometry} /> : null}
    </section>
  );

  function handleDrawingClick(point: Vec2) {
    if (selectedFacetId === undefined) {
      return;
    }

    if (activeTool === 'line') {
      if (pendingPoints.length === 0) {
        setPendingPoints([point]);
      } else {
        commitSegments([createSegment(pendingPoints[0], point)]);
        setPendingPoints([]);
        setPreviewPoint(undefined);
      }
    } else if (activeTool === 'rectangle') {
      if (pendingPoints.length === 0) {
        setPendingPoints([point]);
      } else {
        commitSegments(createRectangleSegments(pendingPoints[0], point));
        setPendingPoints([]);
        setPreviewPoint(undefined);
      }
    } else if (activeTool === 'circle') {
      if (pendingPoints.length === 0) {
        setPendingPoints([point]);
      } else {
        commitSegments(createCircleSegments(pendingPoints[0], point));
        setPendingPoints([]);
        setPreviewPoint(undefined);
      }
    } else if (activeTool === 'polyline') {
      if (pendingPoints.length > 0) {
        commitSegments([createSegment(pendingPoints[pendingPoints.length - 1], point)]);
      }
      setPendingPoints((points) => [...points, point]);
    } else if (activeTool === 'polygon') {
      setPendingPoints((points) => [...points, point]);
    }
  }

  function commitPendingPath(closed: boolean) {
    if (pendingPoints.length < (closed ? 3 : 2)) {
      setPendingPoints([]);
      setPreviewPoint(undefined);
      return;
    }

    commitSegments(createPolylineSegments(pendingPoints, closed));
    setPendingPoints([]);
    setPreviewPoint(undefined);
  }

  function commitSegments(segments: readonly LineSegment2D[]) {
    if (selectedFacetId === undefined || segments.length === 0) {
      return;
    }

    const selected = getSelectedFacetLocalGeometry();
    if (!selected || !segments.every((segment) => isPointInsideFacetLocal(segment.start, selected.localGeometry.boundary) && isPointInsideFacetLocal(segment.end, selected.localGeometry.boundary))) {
      return;
    }

    const pattern = project.patterns[selectedFacetId] ?? createEmptyPattern(selectedFacetId);
    const committedSegments = createSymmetricSegments(segments, radialSymmetryEnabled, radialSymmetryOrder).map((segment) => ({
      ...segment,
      start: inverseTransformPoint(segment.start, pattern.transform),
      end: inverseTransformPoint(segment.end, pattern.transform),
    }));
    onPatternCommit(selectedFacetId, {
      ...pattern,
      segments: [...pattern.segments, ...committedSegments],
    });
  }

  function getSelectedFacetLocalGeometry() {
    const geometry = project.geometry;
    const facet = selectedFacetId !== undefined ? geometry?.facets.find((item) => item.id === selectedFacetId) : undefined;
    if (!geometry || !facet) {
      return undefined;
    }

    return { geometry, facet, localGeometry: createFacetLocalGeometry(geometry, facet) };
  }

  function getRawLocalPoint(clientX: number, clientY: number) {
    const canvas = canvasRef.current;
    const camera = cameraRef.current;
    const selected = getSelectedFacetLocalGeometry();
    if (!canvas || !camera || !selected) {
      return undefined;
    }

    return pickLocalPointOnFacetPlane(clientX, clientY, canvas, camera, selected.facet, selected.localGeometry);
  }

  function getSnappedLocalPoint(clientX: number, clientY: number) {
    const rawPoint = getRawLocalPoint(clientX, clientY);
    const canvas = canvasRef.current;
    const camera = cameraRef.current;
    const selected = getSelectedFacetLocalGeometry();
    if (!rawPoint || !canvas || !camera || !selected) {
      return rawPoint;
    }

    const pattern = selectedFacetId !== undefined ? project.patterns[selectedFacetId] : undefined;
    return snapPoint(rawPoint, createSnapCandidates(clientX, clientY, selected.localGeometry, pattern, camera, canvas), gridSnap, snapEnabled);
  }

  function createSnapCandidates(
    clientX: number,
    clientY: number,
    localGeometry: ReturnType<typeof createFacetLocalGeometry>,
    pattern: Pattern | undefined,
    camera: AppCamera,
    canvas: HTMLCanvasElement,
  ): SnapCandidate[] {
    const patternEndpoints = createPatternEndpointCandidates(pattern).map((point) => ({
      point: pattern ? transformPoint(point, pattern.transform) : point,
      priority: 1,
    }));
    const boundaryPoints = localGeometry.boundary.map((point) => ({ point, priority: 2 }));
    const origin = [{ point: { u: 0, v: 0 }, priority: 3 }];
    return [...patternEndpoints, ...boundaryPoints, ...origin].map((candidate) => ({
      ...candidate,
      screenDistancePx: screenDistanceToLocalPoint(candidate.point, clientX, clientY, localGeometry, camera, canvas),
    }));
  }

  function hitTestPatternScreen(pattern: Pattern, clientX: number, clientY: number): PatternHit | undefined {
    const canvas = canvasRef.current;
    const camera = cameraRef.current;
    const selected = getSelectedFacetLocalGeometry();
    if (!canvas || !camera || !selected) {
      return undefined;
    }

    for (const segment of pattern.segments) {
      const transformed = transformSegment(segment, pattern.transform);
      const start = projectLocalPointToScreen(transformed.start, selected.localGeometry, camera, canvas);
      const end = projectLocalPointToScreen(transformed.end, selected.localGeometry, camera, canvas);
      if (Math.hypot(clientX - start.x, clientY - start.y) <= SNAP_DISTANCE_PX) {
        return { segmentId: segment.id, endpoint: 'start' as const };
      }
      if (Math.hypot(clientX - end.x, clientY - end.y) <= SNAP_DISTANCE_PX) {
        return { segmentId: segment.id, endpoint: 'end' as const };
      }
    }

    let closest: PatternHit | undefined;
    let closestDistance = Infinity;
    for (const segment of pattern.segments) {
      const transformed = transformSegment(segment, pattern.transform);
      const start = projectLocalPointToScreen(transformed.start, selected.localGeometry, camera, canvas);
      const end = projectLocalPointToScreen(transformed.end, selected.localGeometry, camera, canvas);
      const distance = distanceScreenPointToSegment({ x: clientX, y: clientY }, start, end);
      if (distance <= SNAP_DISTANCE_PX && distance < closestDistance) {
        closest = { segmentId: segment.id };
        closestDistance = distance;
      }
    }

    return closest;
  }
}

const MODEL_PREVIEW_PIXELS_PER_MM = 2;

function ModelScalePreview({ geometry }: { readonly geometry: GemGeometry }) {
  const preview = useMemo(() => {
    const center = geometry.boundingBox.center;
    const projectPoint = (index: number) => {
      const point = geometry.vertices[index];
      const x = point.x - center.x;
      const y = point.y - center.y;
      const z = point.z - center.z;
      return {
        x: (x - z) * 0.8660254 * MODEL_PREVIEW_PIXELS_PER_MM,
        y: -(y + (x + z) * 0.35) * MODEL_PREVIEW_PIXELS_PER_MM,
        depth: x + y + z,
      };
    };
    const stride = Math.max(1, Math.ceil(geometry.triangles.length / 700));
    const faces = geometry.triangles
      .filter((_, index) => index % stride === 0)
      .map((triangle) => {
        const points = [projectPoint(triangle.a), projectPoint(triangle.b), projectPoint(triangle.c)];
        return { points, depth: points.reduce((sum, point) => sum + point.depth, 0) / 3 };
      })
      .sort((a, b) => a.depth - b.depth);
    const size = geometry.boundingBox.size;
    return {
      faces,
      maximumSize: Math.max(size.x, size.y, size.z),
    };
  }, [geometry]);

  return (
    <figure className="modelScalePreview" aria-label="Current model shown against a 10 millimeter reference">
      <svg viewBox="-90 -72 180 144" aria-hidden="true">
        <g className="modelScaleGem">
          {preview.faces.map((face, index) => (
            <polygon key={index} points={face.points.map((point) => `${point.x},${point.y}`).join(' ')} />
          ))}
        </g>
        <g className="modelScaleRuler">
          <line x1="-80" y1="59" x2="-60" y2="59" />
          <line x1="-80" y1="55" x2="-80" y2="63" />
          <line x1="-60" y1="55" x2="-60" y2="63" />
          <text x="-70" y="52" textAnchor="middle">10 mm</text>
        </g>
      </svg>
      <figcaption>Model max {preview.maximumSize.toFixed(1)} mm</figcaption>
    </figure>
  );
}

function applyCleanRenderVisibility(scene: THREE.Scene, clean: boolean) {
  scene.traverse((object) => {
    if (object === scene) {
      return;
    }
    if (object.userData.cleanRenderOriginalVisible === undefined) {
      object.userData.cleanRenderOriginalVisible = object.visible;
    }

    if (!clean) {
      object.visible = object.userData.cleanRenderOriginalVisible;
      return;
    }

    const keepVisible = object instanceof THREE.Camera || object.type.includes('Light') || object.name === 'Gem geometry';
    object.visible = keepVisible;
  });
}

function createPreviewSegments(
  activeTool: PatternTool,
  pendingPoints: readonly Vec2[],
  previewPoint: Vec2 | undefined,
): LineSegment2D[] {
  if (!previewPoint || pendingPoints.length === 0) {
    return [];
  }

  if (activeTool === 'line' || activeTool === 'polyline') {
    return [previewSegment(pendingPoints[pendingPoints.length - 1], previewPoint)];
  }
  if (activeTool === 'rectangle') {
    return createRectangleSegments(pendingPoints[0], previewPoint);
  }
  if (activeTool === 'circle') {
    return createCircleSegments(pendingPoints[0], previewPoint, 48);
  }
  if (activeTool === 'polygon') {
    return createPolylineSegments([...pendingPoints, previewPoint], false).map((segment) => ({ ...segment, id: `preview-${segment.id}` }));
  }

  return [];
}

function previewSegment(start: Vec2, end: Vec2): LineSegment2D {
  return { id: 'preview-segment', start, end };
}

function createSymmetricSegments(
  segments: readonly LineSegment2D[],
  enabled: boolean,
  order: number,
): LineSegment2D[] {
  if (!enabled || order <= 1 || segments.length === 0) {
    return [...segments];
  }

  return circularArraySegments(segments, Math.max(2, order), { u: 0, v: 0 }, 360, 0);
}

function screenDistanceToLocalPoint(
  point: Vec2,
  clientX: number,
  clientY: number,
  localGeometry: ReturnType<typeof createFacetLocalGeometry>,
  camera: AppCamera,
  canvas: HTMLCanvasElement,
) {
  const screen = projectLocalPointToScreen(point, localGeometry, camera, canvas);
  return Math.hypot(clientX - screen.x, clientY - screen.y);
}

function projectLocalPointToScreen(
  point: Vec2,
  localGeometry: ReturnType<typeof createFacetLocalGeometry>,
  camera: AppCamera,
  canvas: HTMLCanvasElement,
) {
  const world = new THREE.Vector3(
    localGeometry.frame.origin.x +
      localGeometry.frame.uAxis.x * point.u +
      localGeometry.frame.vAxis.x * point.v,
    localGeometry.frame.origin.y +
      localGeometry.frame.uAxis.y * point.u +
      localGeometry.frame.vAxis.y * point.v,
    localGeometry.frame.origin.z +
      localGeometry.frame.uAxis.z * point.u +
      localGeometry.frame.vAxis.z * point.v,
  );
  const projected = world.project(camera);
  const rect = canvas.getBoundingClientRect();
  return {
    x: rect.left + ((projected.x + 1) / 2) * rect.width,
    y: rect.top + ((-projected.y + 1) / 2) * rect.height,
  };
}

function distanceScreenPointToSegment(
  point: { readonly x: number; readonly y: number },
  start: { readonly x: number; readonly y: number },
  end: { readonly x: number; readonly y: number },
) {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const lengthSquared = dx * dx + dy * dy;
  if (lengthSquared === 0) {
    return Math.hypot(point.x - start.x, point.y - start.y);
  }

  const t = Math.max(0, Math.min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared));
  return Math.hypot(point.x - (start.x + t * dx), point.y - (start.y + t * dy));
}

function fitCameraToBoundingBox(
  camera: AppCamera,
  controls: ViewportControls,
  boundingBox: BoundingBox,
) {
  const center = new THREE.Vector3(boundingBox.center.x, boundingBox.center.y, boundingBox.center.z);
  const size = new THREE.Vector3(boundingBox.size.x, boundingBox.size.y, boundingBox.size.z);
  const radius = Math.max(size.length() / 2, 1);
  const direction = new THREE.Vector3(1, 0.75, 1).normalize();

  controls.target.copy(center);

  if ('isPerspectiveCamera' in camera && camera.isPerspectiveCamera) {
    const fovRadians = THREE.MathUtils.degToRad(camera.fov);
    const distance = radius / Math.sin(fovRadians / 2);
    camera.position.copy(center.clone().add(direction.multiplyScalar(distance * 1.25)));
  } else {
    camera.zoom = Math.max(0.1, Math.min(100, 3 / radius));
    camera.position.copy(center.clone().add(direction.multiplyScalar(radius * 4)));
    camera.updateProjectionMatrix();
  }

  camera.lookAt(center);
  controls.update();
}

function snapshotCamera(camera: AppCamera, target: THREE.Vector3): CameraSnapshot {
  return {
    position: [camera.position.x, camera.position.y, camera.position.z],
    target: [target.x, target.y, target.z],
  };
}

function formatError(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}
