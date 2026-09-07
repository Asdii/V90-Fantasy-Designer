import { useEffect, useRef, useState } from 'react';
import {
  createLinePrimitive,
  type DesignPattern,
  type PatternPrimitive,
  type PrimitiveRole,
  type Vec2,
} from '../patterns/model/PatternModel';
import { calculateDesignPatternBounds, calculatePrimitiveBounds } from '../patterns/geometry/bounds';
import { normalizePattern, patternToCutPaths } from '../patterns/geometry/pathConversion';
import { mirrorPrimitive, radialDuplicatePrimitives, transformPrimitive } from '../patterns/geometry/transforms';
import { createRegularPolygonPrimitive } from '../patterns/editor/RegularPolygon';
import { createCenteredRectanglePrimitive } from '../patterns/editor/Rectangle';
import { snapEditorPoint, snapRegularShapePoint } from '../patterns/editor/SnapEngine';
import type { PatternReferenceImage } from '../patterns/editor/PatternReferenceImage';
import {
  createPatternViewportState,
  fitBoundsInViewport,
  getVisibleWorldBounds,
  resizePatternViewport,
  resetPatternViewport,
  screenToWorld,
  worldToScreen,
  zoomPatternViewportAt,
} from '../patterns/editor/PatternViewport';

type DesignerTool = 'select' | 'line' | 'rectangle' | 'triangle' | 'pentagon' | 'hexagon';
type PointerDrag =
  | { readonly type: 'pan'; readonly startClient: { readonly x: number; readonly y: number }; readonly startPan: { readonly x: number; readonly y: number } }
  | { readonly type: 'move'; readonly startWorld: Vec2; readonly original: DesignPattern }
  | { readonly type: 'referenceImage'; readonly startWorld: Vec2; readonly startCenter: Vec2 };

interface PatternDesignerProps {
  readonly pattern: DesignPattern;
  readonly onPatternChange: (pattern: DesignPattern) => void;
  readonly referenceImage?: PatternReferenceImage;
  readonly onReferenceImageChange?: (image: PatternReferenceImage | undefined) => void;
  readonly keyboardActive?: boolean;
}

const tools: DesignerTool[] = ['select', 'line', 'rectangle', 'triangle', 'hexagon', 'pentagon'];
const gridOptions = [1, 0.5, 0.1];

export function PatternDesigner({ pattern, onPatternChange, referenceImage, onReferenceImageChange, keyboardActive = true }: PatternDesignerProps) {
  const svgRef = useRef<SVGSVGElement | null>(null);
  const undoStackRef = useRef<DesignPattern[]>([]);
  const redoStackRef = useRef<DesignPattern[]>([]);
  const dragChangedRef = useRef(false);
  const [tool, setTool] = useState<DesignerTool>('select');
  const [role, setRole] = useState<PrimitiveRole>('pattern');
  const [snapEnabled, setSnapEnabled] = useState(true);
  const [gridSpacing, setGridSpacing] = useState(1);
  const [viewport, setViewport] = useState(() => createPatternViewportState());
  const [cursor, setCursor] = useState<Vec2 | undefined>();
  const [pendingPoints, setPendingPoints] = useState<Vec2[]>([]);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [clipboard, setClipboard] = useState<PatternPrimitive[]>([]);
  const [drag, setDrag] = useState<PointerDrag | undefined>();
  const [shapeRotationDeg, setShapeRotationDeg] = useState<number | undefined>();
  const [radialCopies, setRadialCopies] = useState(8);
  const [radialCenterX, setRadialCenterX] = useState(0);
  const [radialCenterY, setRadialCenterY] = useState(0);
  const [radialAngle, setRadialAngle] = useState(360);
  const [symmetryEnabled, setSymmetryEnabled] = useState(false);
  const [symmetryOrder, setSymmetryOrder] = useState(8);
  const [transformX, setTransformX] = useState(0);
  const [transformY, setTransformY] = useState(0);
  const [transformRotation, setTransformRotation] = useState(0);
  const [transformScale, setTransformScale] = useState(1);
  const [showPatternData, setShowPatternData] = useState(false);
  const [moveReferenceImage, setMoveReferenceImage] = useState(false);

  const selectedPrimitives = pattern.primitives.filter((primitive) => selectedIds.includes(primitive.id));
  const bounds = calculateDesignPatternBounds(pattern);
  const cutPaths = patternToCutPaths(pattern);
  const previewPrimitive = createPreviewPrimitive(tool, pendingPoints, cursor, role, shapeRotationDeg);
  const previewPrimitives = previewPrimitive ? applyDrawingSymmetry([previewPrimitive]) : [];

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (!keyboardActive) {
        return;
      }
      const key = event.key.toLowerCase();
      const editableTarget = event.target instanceof HTMLElement
        && (event.target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(event.target.tagName));
      if (event.key === 'Escape') {
        setPendingPoints([]);
        setCursor(undefined);
        return;
      }
      if ((event.key === 'Delete' || event.key === 'Backspace') && selectedIds.length > 0) {
        commitPatternChange({ ...pattern, primitives: pattern.primitives.filter((primitive) => !selectedIds.includes(primitive.id)) });
        setSelectedIds([]);
        return;
      }
      if (!(event.ctrlKey || event.metaKey)) {
        return;
      }
      if (key === 'z' && !editableTarget) {
        event.preventDefault();
        if (event.shiftKey) {
          redoPatternChange();
        } else {
          undoPatternChange();
        }
      } else if (key === 'y' && !editableTarget) {
        event.preventDefault();
        redoPatternChange();
      } else if (key === 'c') {
        setClipboard([...selectedPrimitives]);
      } else if (key === 'v') {
        pasteClipboard();
      } else if (key === 'd') {
        duplicateSelection();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [clipboard, keyboardActive, onPatternChange, pattern, selectedIds, selectedPrimitives, tool]);

  useEffect(() => {
    const svg = svgRef.current;
    if (!svg) {
      return;
    }

    const updateSize = () => {
      const rect = svg.getBoundingClientRect();
      setViewport((current) => resizePatternViewport(current, rect.width, rect.height));
    };
    const resizeObserver = new ResizeObserver(updateSize);
    resizeObserver.observe(svg);
    updateSize();

    return () => resizeObserver.disconnect();
  }, []);

  return (
    <main className="patternDesignerShell">
      <header className="patternDesignerTabs">
        <div className="toolbarGroup">
          {tools.map((item) => (
            <button key={item} className={tool === item ? 'toolbarButton active' : 'toolbarButton'} onClick={() => setTool(item)}>
              {toolLabel(item)}
            </button>
          ))}
        </div>
        <div className="toolbarGroup">
          <label className="wireframeToggle">
            <input type="checkbox" checked={snapEnabled} onChange={(event) => setSnapEnabled(event.target.checked)} />
            Snap
          </label>
          <label>
            Grid
            <select className="toolbarSelect" value={gridSpacing} onChange={(event) => setGridSpacing(Number(event.target.value))}>
              {gridOptions.map((value) => (
                <option key={value} value={value}>
                  {value.toFixed(1)}
                </option>
              ))}
            </select>
          </label>
          <label className="wireframeToggle">
            <input type="checkbox" checked={role === 'construction'} onChange={(event) => setRole(event.target.checked ? 'construction' : 'pattern')} />
            Construction
          </label>
          <button
            className={moveReferenceImage ? 'toolbarButton active' : 'toolbarButton'}
            disabled={!referenceImage}
            onClick={() => setMoveReferenceImage((current) => !current)}
          >
            Move Photo
          </button>
        </div>
      </header>
      <section className="patternDesignerWorkspace">
        <div className="patternCanvasFrame">
          <svg
            ref={svgRef}
            className="patternCanvas"
            width={viewport.width}
            height={viewport.height}
            viewBox={`0 0 ${viewport.width} ${viewport.height}`}
            onContextMenu={(event) => event.preventDefault()}
            onDoubleClick={() => finishPendingPath()}
            onPointerDown={handlePointerDown}
            onPointerLeave={() => setCursor(undefined)}
            onPointerMove={handlePointerMove}
            onPointerUp={finishPointerDrag}
            onWheel={handleWheel}
          >
            <rect x="0" y="0" width="100%" height="100%" fill="#f7f8fa" />
            {referenceImage ? renderReferenceImage(referenceImage) : null}
            {renderGrid()}
            <line x1="0" y1={toScreen({ x: 0, y: 0 }).y} x2={viewport.width} y2={toScreen({ x: 0, y: 0 }).y} className="axisLine xAxis" />
            <line x1={toScreen({ x: 0, y: 0 }).x} y1="0" x2={toScreen({ x: 0, y: 0 }).x} y2={viewport.height} className="axisLine yAxis" />
            <circle cx={toScreen({ x: 0, y: 0 }).x} cy={toScreen({ x: 0, y: 0 }).y} r="4" className="originPoint" />
            {[...pattern.primitives, ...previewPrimitives].map((primitive) =>
              renderPrimitive(primitive, selectedIds.includes(primitive.id), previewPrimitives.includes(primitive)),
            )}
          </svg>
          <div className="patternDesignerStatus">
            X: {cursor ? cursor.x.toFixed(3) : '-'} mm Y: {cursor ? cursor.y.toFixed(3) : '-'} mm Zoom: {(viewport.zoom / 48).toFixed(2)}x
          </div>
        </div>
        <aside className="patternContextPanel">
          <h2>Pattern Designer</h2>
          <dl>
            <dt>Primitives</dt>
            <dd>{pattern.primitives.length}</dd>
            <dt>Cut paths</dt>
            <dd>{cutPaths.length}</dd>
            <dt>Bounds</dt>
            <dd>
              {bounds.width.toFixed(3)} x {bounds.height.toFixed(3)} mm
            </dd>
          </dl>
          {tool !== 'select' ? (
            <>
              <h3>Radial Symmetry</h3>
              <label className="wireframeToggle">
                <input type="checkbox" checked={symmetryEnabled} onChange={(event) => setSymmetryEnabled(event.target.checked)} />
                Enabled
              </label>
              <NumberInput label="Order" value={symmetryOrder} min={2} step={1} onChange={setSymmetryOrder} />
            </>
          ) : null}
          {selectedPrimitives.length > 0 ? (
            <>
              <h3>Selection</h3>
              <dl>
                <dt>Selected</dt>
                <dd>{selectedPrimitives.length}</dd>
                <dt>Type</dt>
                <dd>{selectedPrimitives.length === 1 ? selectedPrimitives[0].type : 'mixed'}</dd>
              </dl>
              {selectedPrimitives.length === 1 ? <PrimitiveProperties primitive={selectedPrimitives[0]} onChange={replacePrimitive} /> : null}
              <h3>Transform</h3>
              <NumberInput label="Move X" value={transformX} step={0.001} onChange={setTransformX} />
              <NumberInput label="Move Y" value={transformY} step={0.001} onChange={setTransformY} />
              <NumberInput label="Rotation" value={transformRotation} step={1} onChange={setTransformRotation} />
              <NumberInput label="Scale" value={transformScale} min={0.001} step={0.01} onChange={setTransformScale} />
              <div className="patternControls">
                <button
                  className="toolbarButton"
                  onClick={() => transformSelection({ translateX: transformX, translateY: transformY, rotationDeg: transformRotation, scale: transformScale })}
                >
                  Apply Transform
                </button>
                <button
                  className="toolbarButton"
                  onClick={() => {
                    setTransformX(0);
                    setTransformY(0);
                    setTransformRotation(0);
                    setTransformScale(1);
                  }}
                >
                  Reset Fields
                </button>
              </div>
              <div className="patternControls">
                <button className="toolbarButton" onClick={() => mirrorSelection('x')}>
                  Mirror X
                </button>
                <button className="toolbarButton" onClick={() => mirrorSelection('y')}>
                  Mirror Y
                </button>
                <button className="toolbarButton" onClick={convertSelectedRole}>
                  Convert to {selectedPrimitives.some((primitive) => primitive.role === 'pattern') ? 'Construction' : 'Pattern'}
                </button>
              </div>
              <h3>Radial Duplicate</h3>
              <NumberInput label="Copies" value={radialCopies} min={1} step={1} onChange={setRadialCopies} />
              <NumberInput label="Center X" value={radialCenterX} step={0.001} onChange={setRadialCenterX} />
              <NumberInput label="Center Y" value={radialCenterY} step={0.001} onChange={setRadialCenterY} />
              <NumberInput label="Angle" value={radialAngle} step={1} onChange={setRadialAngle} />
              <button className="toolbarButton" onClick={applyRadialDuplicate}>
                Apply
              </button>
            </>
          ) : (
            <p>Select geometry to edit properties or transforms.</p>
          )}
          <h3>Actions</h3>
          <div className="patternControls">
            <button className="toolbarButton" onClick={duplicateSelection} disabled={selectedPrimitives.length === 0}>
              Duplicate
            </button>
            <button className="toolbarButton" onClick={() => commitPatternChange({ ...pattern, primitives: [] })}>
              Clear
            </button>
            <button className="toolbarButton" onClick={() => commitPatternChange(normalizePattern(pattern))}>
              Normalize Copy
            </button>
            <button className="toolbarButton" onClick={fitPatternView}>
              Fit Pattern
            </button>
            <button className="toolbarButton" onClick={() => setViewport((current) => resetPatternViewport(current))}>
              Reset View
            </button>
          </div>
          {referenceImage ? (
            <>
              <h3>Reference Photo</h3>
              <NumberInput
                label="Opacity"
                value={referenceImage.opacity}
                min={0.05}
                step={0.05}
                onChange={(opacity) => onReferenceImageChange?.({ ...referenceImage, opacity: Math.min(1, Math.max(0.05, opacity)) })}
              />
              <button className="toolbarButton" onClick={() => onReferenceImageChange?.(undefined)}>Remove Photo</button>
            </>
          ) : null}
          <label className="wireframeToggle">
            <input type="checkbox" checked={showPatternData} onChange={(event) => setShowPatternData(event.target.checked)} />
            Pattern Data
          </label>
          {showPatternData ? <PatternData pattern={pattern} /> : null}
        </aside>
      </section>
    </main>
  );

  function handlePointerDown(event: React.PointerEvent<SVGSVGElement>) {
    if (event.button === 1 || event.button === 2) {
      setDrag({
        type: 'pan',
        startClient: { x: event.clientX, y: event.clientY },
        startPan: { x: viewport.panX, y: viewport.panY },
      });
      return;
    }

    if (moveReferenceImage && referenceImage) {
      setDrag({
        type: 'referenceImage',
        startWorld: getRawPoint(event),
        startCenter: referenceImage.center,
      });
      event.currentTarget.setPointerCapture(event.pointerId);
      return;
    }

    const point = getToolPoint(event);

    if (tool === 'select') {
      const hit = hitTest(point);
      if (hit) {
        setSelectedIds((ids) => (event.shiftKey ? toggleId(ids, hit.id) : [hit.id]));
        if (selectedIds.includes(hit.id)) {
          dragChangedRef.current = false;
          setDrag({ type: 'move', startWorld: point, original: pattern });
        }
      } else if (!event.shiftKey) {
        setSelectedIds([]);
      }
      return;
    }

    addToolPoint(point, event.ctrlKey || event.metaKey);
  }

  function handlePointerMove(event: React.PointerEvent<SVGSVGElement>) {
    if (drag?.type === 'pan') {
      const dx = event.clientX - drag.startClient.x;
      const dy = event.clientY - drag.startClient.y;
      setViewport((current) => ({ ...current, panX: drag.startPan.x + dx, panY: drag.startPan.y + dy }));
      return;
    }

    if (drag?.type === 'referenceImage' && referenceImage) {
      const raw = getRawPoint(event);
      onReferenceImageChange?.({
        ...referenceImage,
        center: {
          x: drag.startCenter.x + raw.x - drag.startWorld.x,
          y: drag.startCenter.y + raw.y - drag.startWorld.y,
        },
      });
      setCursor(raw);
      return;
    }

    const point = getToolPoint(event);
    setCursor(point);
    if (pendingPoints.length === 1 && isShapeTool(tool)) {
      setShapeRotationDeg(event.ctrlKey || event.metaKey ? snapAngle(angleDeg(pendingPoints[0], point), 15) : undefined);
    }
    if (drag?.type === 'move') {
      const dx = point.x - drag.startWorld.x;
      const dy = point.y - drag.startWorld.y;
      dragChangedRef.current = Math.abs(dx) > 1e-12 || Math.abs(dy) > 1e-12;
      onPatternChange({
        ...drag.original,
        primitives: drag.original.primitives.map((primitive) =>
          selectedIds.includes(primitive.id)
            ? transformPrimitive(primitive, { translateX: dx, translateY: dy, rotationDeg: 0, scale: 1, center: { x: 0, y: 0 } })
            : primitive,
        ),
      });
    }
  }

  function finishPointerDrag() {
    if (drag?.type === 'move' && dragChangedRef.current) {
      recordUndoSnapshot(drag.original);
    }
    dragChangedRef.current = false;
    setDrag(undefined);
  }

  function handleWheel(event: React.WheelEvent<SVGSVGElement>) {
    event.preventDefault();
    const factor = event.deltaY < 0 ? 1.12 : 0.88;
    const local = clientToViewportPoint(event.clientX, event.clientY);
    setViewport((current) => zoomPatternViewportAt(current, local, factor));
  }

  function addToolPoint(point: Vec2, rotateWithSnap: boolean) {
    if (tool === 'line') {
      if (pendingPoints.length === 0) {
        setPendingPoints([point]);
      } else {
        appendPrimitives([createLinePrimitive(pendingPoints[0], point, role)]);
        setPendingPoints([]);
      }
    } else if (isShapeTool(tool)) {
      if (pendingPoints.length === 0) {
        setPendingPoints([point]);
        setShapeRotationDeg(undefined);
      } else {
        appendPrimitives([createShapePrimitive(tool, pendingPoints[0], point, role, rotateWithSnap ? snapAngle(angleDeg(pendingPoints[0], point), 15) : shapeRotationDeg)]);
        setPendingPoints([]);
        setShapeRotationDeg(undefined);
      }
    }
  }

  function finishPendingPath() {
    setPendingPoints([]);
    setShapeRotationDeg(undefined);
  }

  function appendPrimitives(primitives: readonly PatternPrimitive[]) {
    commitPatternChange({ ...pattern, primitives: [...pattern.primitives, ...applyDrawingSymmetry(primitives)] });
  }

  function applyDrawingSymmetry(primitives: readonly PatternPrimitive[]) {
    if (!symmetryEnabled) {
      return [...primitives];
    }

    return radialDuplicatePrimitives(primitives, Math.max(2, Math.round(symmetryOrder)), { x: 0, y: 0 }, 360);
  }

  function replacePrimitive(next: PatternPrimitive) {
    commitPatternChange({ ...pattern, primitives: pattern.primitives.map((primitive) => (primitive.id === next.id ? next : primitive)) });
  }

  function duplicateSelection() {
    if (selectedPrimitives.length === 0) {
      return;
    }
    const copies = selectedPrimitives.map((primitive) =>
      transformPrimitive(primitive, { translateX: gridSpacing, translateY: -gridSpacing, rotationDeg: 0, scale: 1, center: { x: 0, y: 0 } }),
    );
    commitPatternChange({ ...pattern, primitives: [...pattern.primitives, ...copies] });
    setSelectedIds(copies.map((primitive) => primitive.id));
  }

  function pasteClipboard() {
    if (clipboard.length === 0) {
      return;
    }
    const copies = clipboard.map((primitive) =>
      transformPrimitive(primitive, { translateX: gridSpacing, translateY: -gridSpacing, rotationDeg: 0, scale: 1, center: { x: 0, y: 0 } }),
    );
    commitPatternChange({ ...pattern, primitives: [...pattern.primitives, ...copies] });
    setSelectedIds(copies.map((primitive) => primitive.id));
  }

  function mirrorSelection(axis: 'x' | 'y') {
    const copies = selectedPrimitives.map((primitive) => mirrorPrimitive(primitive, axis));
    commitPatternChange({ ...pattern, primitives: [...pattern.primitives, ...copies] });
    setSelectedIds(copies.map((primitive) => primitive.id));
  }

  function transformSelection(partial: { readonly translateX: number; readonly translateY: number; readonly rotationDeg: number; readonly scale: number }) {
    const center = calculateSelectionCenter(selectedPrimitives);
    commitPatternChange({
      ...pattern,
      primitives: pattern.primitives.map((primitive) =>
        selectedIds.includes(primitive.id) ? transformPrimitive(primitive, { ...partial, center }) : primitive,
      ),
    });
  }

  function applyRadialDuplicate() {
    const duplicates = radialDuplicatePrimitives(selectedPrimitives, radialCopies, { x: radialCenterX, y: radialCenterY }, radialAngle).slice(selectedPrimitives.length);
    commitPatternChange({ ...pattern, primitives: [...pattern.primitives, ...duplicates] });
    setSelectedIds(duplicates.map((primitive) => primitive.id));
  }

  function convertSelectedRole() {
    commitPatternChange({
      ...pattern,
      primitives: pattern.primitives.map((primitive) =>
        selectedIds.includes(primitive.id)
          ? { ...primitive, role: primitive.role === 'pattern' ? 'construction' : 'pattern' }
          : primitive,
      ),
    });
  }

  function getSnappedPoint(event: React.PointerEvent<SVGSVGElement>): Vec2 {
    const raw = getRawPoint(event);
    return snapEditorPoint(raw, pattern, { enabled: snapEnabled, gridSpacing, snapDistanceWorld: 10 / viewport.zoom }).point;
  }

  function getRawPoint(event: React.PointerEvent<SVGSVGElement>): Vec2 {
    return toWorld(clientToViewportPoint(event.clientX, event.clientY));
  }

  function getToolPoint(event: React.PointerEvent<SVGSVGElement>): Vec2 {
    if (pendingPoints.length === 1 && isRegularShapeTool(tool)) {
      return snapRegularShapePoint(getRawPoint(event), pattern, {
        center: pendingPoints[0],
        enabled: snapEnabled,
        gridSpacing,
        snapDistanceWorld: 10 / viewport.zoom,
        angleStepDeg: event.ctrlKey || event.metaKey ? 15 : undefined,
      });
    }
    return getSnappedPoint(event);
  }

  function commitPatternChange(next: DesignPattern) {
    recordUndoSnapshot(pattern);
    onPatternChange(next);
  }

  function recordUndoSnapshot(snapshot: DesignPattern) {
    undoStackRef.current.push(snapshot);
    redoStackRef.current = [];
  }

  function undoPatternChange() {
    const previous = undoStackRef.current.pop();
    if (!previous) {
      return;
    }
    redoStackRef.current.push(pattern);
    setSelectedIds([]);
    setPendingPoints([]);
    onPatternChange(previous);
  }

  function redoPatternChange() {
    const next = redoStackRef.current.pop();
    if (!next) {
      return;
    }
    undoStackRef.current.push(pattern);
    setSelectedIds([]);
    setPendingPoints([]);
    onPatternChange(next);
  }

  function clientToViewportPoint(clientX: number, clientY: number): Vec2 {
    const rect = svgRef.current?.getBoundingClientRect();
    if (!rect) {
      return { x: 0, y: 0 };
    }
    return { x: clientX - rect.left, y: clientY - rect.top };
  }

  function toWorld(point: Vec2): Vec2 {
    return screenToWorld(point, viewport);
  }

  function toScreen(point: Vec2): Vec2 {
    return worldToScreen(point, viewport);
  }

  function renderGrid() {
    const bounds = getVisibleWorldBounds(viewport);
    const visualSpacing = chooseVisibleGridSpacing(gridSpacing, viewport.zoom);
    const lines = [];
    const startX = Math.floor(bounds.minX / visualSpacing) * visualSpacing;
    const endX = Math.ceil(bounds.maxX / visualSpacing) * visualSpacing;
    const startY = Math.floor(bounds.minY / visualSpacing) * visualSpacing;
    const endY = Math.ceil(bounds.maxY / visualSpacing) * visualSpacing;

    for (let x = startX; x <= endX; x += visualSpacing) {
      const screen = toScreen({ x, y: 0 });
      const major = isMajorGridLine(x, gridSpacing);
      lines.push(<line key={`gx-${x}`} x1={screen.x} y1="0" x2={screen.x} y2={viewport.height} className={major ? 'gridLine majorGridLine' : 'gridLine'} />);
    }
    for (let y = startY; y <= endY; y += visualSpacing) {
      const screen = toScreen({ x: 0, y });
      const major = isMajorGridLine(y, gridSpacing);
      lines.push(<line key={`gy-${y}`} x1="0" y1={screen.y} x2={viewport.width} y2={screen.y} className={major ? 'gridLine majorGridLine' : 'gridLine'} />);
    }
    return lines;
  }

  function renderReferenceImage(image: PatternReferenceImage) {
    const width = image.naturalWidth * image.mmPerPixel;
    const height = image.naturalHeight * image.mmPerPixel;
    const topLeft = toScreen({ x: image.center.x - width / 2, y: image.center.y + height / 2 });
    return (
      <image
        href={image.dataUrl}
        x={topLeft.x}
        y={topLeft.y}
        width={width * viewport.zoom}
        height={height * viewport.zoom}
        opacity={image.opacity}
        preserveAspectRatio="none"
        pointerEvents="none"
      />
    );
  }

  function renderPrimitive(primitive: PatternPrimitive, selected: boolean, preview: boolean) {
    const className = ['primitive', primitive.role === 'construction' ? 'constructionPrimitive' : 'patternPrimitive', selected ? 'selectedPrimitive' : '', preview ? 'previewPrimitive' : ''].join(' ');
    if (primitive.type === 'line') {
      const start = toScreen(primitive.start);
      const end = toScreen(primitive.end);
      return <line key={primitive.id} x1={start.x} y1={start.y} x2={end.x} y2={end.y} className={className} />;
    }
    if (primitive.type === 'polyline') {
      const points = primitive.points.map((point) => `${toScreen(point).x},${toScreen(point).y}`).join(' ');
      return primitive.closed
        ? <polygon key={primitive.id} points={points} className={className} />
        : <polyline key={primitive.id} points={points} className={className} />;
    }
    if (primitive.type === 'circle') {
      const center = toScreen(primitive.center);
      return <circle key={primitive.id} cx={center.x} cy={center.y} r={primitive.radius * viewport.zoom} className={className} />;
    }
    return <path key={primitive.id} d={arcPath(primitive)} className={className} />;
  }

  function arcPath(primitive: Extract<PatternPrimitive, { type: 'arc' }>) {
    const start = toScreen(pointOnCircle(primitive.center, primitive.radius, primitive.startAngleDeg));
    const end = toScreen(pointOnCircle(primitive.center, primitive.radius, primitive.endAngleDeg));
    const largeArc = Math.abs(primitive.endAngleDeg - primitive.startAngleDeg) > 180 ? 1 : 0;
    const sweep = primitive.endAngleDeg >= primitive.startAngleDeg ? 0 : 1;
    return `M ${start.x} ${start.y} A ${primitive.radius * viewport.zoom} ${primitive.radius * viewport.zoom} 0 ${largeArc} ${sweep} ${end.x} ${end.y}`;
  }

  function hitTest(point: Vec2) {
    const tolerance = 8 / viewport.zoom;
    for (const primitive of [...pattern.primitives].reverse()) {
      if (distanceToPrimitive(point, primitive) <= tolerance) {
        return primitive;
      }
    }
    return undefined;
  }

  function fitPatternView() {
    setViewport((current) => fitBoundsInViewport(current, bounds));
  }
}

function PrimitiveProperties({ primitive, onChange }: { readonly primitive: PatternPrimitive; readonly onChange: (primitive: PatternPrimitive) => void }) {
  if (primitive.type === 'line') {
    return (
      <>
        <h3>Line</h3>
        <NumberInput label="Start X" value={primitive.start.x} step={0.001} onChange={(x) => onChange({ ...primitive, start: { ...primitive.start, x } })} />
        <NumberInput label="Start Y" value={primitive.start.y} step={0.001} onChange={(y) => onChange({ ...primitive, start: { ...primitive.start, y } })} />
        <NumberInput label="End X" value={primitive.end.x} step={0.001} onChange={(x) => onChange({ ...primitive, end: { ...primitive.end, x } })} />
        <NumberInput label="End Y" value={primitive.end.y} step={0.001} onChange={(y) => onChange({ ...primitive, end: { ...primitive.end, y } })} />
        <dl>
          <dt>Length</dt>
          <dd>{distance(primitive.start, primitive.end).toFixed(3)} mm</dd>
          <dt>Angle</dt>
          <dd>{angleDeg(primitive.start, primitive.end).toFixed(3)} deg</dd>
        </dl>
      </>
    );
  }
  if (primitive.type === 'circle') {
    return (
      <>
        <h3>Circle</h3>
        <NumberInput label="Center X" value={primitive.center.x} step={0.001} onChange={(x) => onChange({ ...primitive, center: { ...primitive.center, x } })} />
        <NumberInput label="Center Y" value={primitive.center.y} step={0.001} onChange={(y) => onChange({ ...primitive, center: { ...primitive.center, y } })} />
        <NumberInput label="Radius" value={primitive.radius} min={0} step={0.001} onChange={(radius) => onChange({ ...primitive, radius })} />
      </>
    );
  }
  if (primitive.type === 'arc') {
    return (
      <>
        <h3>Arc</h3>
        <NumberInput label="Center X" value={primitive.center.x} step={0.001} onChange={(x) => onChange({ ...primitive, center: { ...primitive.center, x } })} />
        <NumberInput label="Center Y" value={primitive.center.y} step={0.001} onChange={(y) => onChange({ ...primitive, center: { ...primitive.center, y } })} />
        <NumberInput label="Radius" value={primitive.radius} min={0} step={0.001} onChange={(radius) => onChange({ ...primitive, radius })} />
        <NumberInput label="Start angle" value={primitive.startAngleDeg} step={1} onChange={(startAngleDeg) => onChange({ ...primitive, startAngleDeg })} />
        <NumberInput label="End angle" value={primitive.endAngleDeg} step={1} onChange={(endAngleDeg) => onChange({ ...primitive, endAngleDeg })} />
      </>
    );
  }
  return (
    <>
      <h3>Polyline</h3>
      <dl>
        <dt>Points</dt>
        <dd>{primitive.points.length}</dd>
        <dt>Closed</dt>
        <dd>{primitive.closed ? 'yes' : 'no'}</dd>
      </dl>
    </>
  );
}

function PatternData({ pattern }: { readonly pattern: DesignPattern }) {
  return (
    <pre className="patternDataText">
      {pattern.primitives
        .map((primitive, index) => `${index + 1}. ${primitive.type} ${primitive.role}\n${JSON.stringify(primitive, null, 2)}`)
        .join('\n\n')}
    </pre>
  );
}

function NumberInput({ label, value, min, max, step, onChange }: { readonly label: string; readonly value: number; readonly min?: number; readonly max?: number; readonly step?: number; readonly onChange: (value: number) => void }) {
  return (
    <label className="numberRow">
      {label}
      <input type="number" min={min} max={max} step={step ?? 0.001} value={Number.isFinite(value) ? value : 0} onChange={(event) => onChange(Number(event.target.value))} />
    </label>
  );
}

function createPreviewPrimitive(tool: DesignerTool, points: readonly Vec2[], cursor: Vec2 | undefined, role: PrimitiveRole, rotationDeg?: number): PatternPrimitive | undefined {
  if (!cursor || points.length === 0) {
    return undefined;
  }
  if (tool === 'line') {
    return { ...createLinePrimitive(points[0], cursor, role), id: 'preview-line' };
  }
  if (isShapeTool(tool)) {
    return { ...createShapePrimitive(tool, points[0], cursor, role, rotationDeg), id: `preview-${tool}` };
  }
  return undefined;
}

function distanceToPrimitive(point: Vec2, primitive: PatternPrimitive): number {
  if (primitive.type === 'line') {
    return distanceToSegment(point, primitive.start, primitive.end);
  }
  if (primitive.type === 'polyline') {
    const distances = [];
    for (let index = 0; index + 1 < primitive.points.length; index += 1) {
      distances.push(distanceToSegment(point, primitive.points[index], primitive.points[index + 1]));
    }
    if (primitive.closed && primitive.points.length > 2) {
      distances.push(distanceToSegment(point, primitive.points[primitive.points.length - 1], primitive.points[0]));
    }
    return Math.min(...distances);
  }
  if (primitive.type === 'circle') {
    return Math.abs(distance(point, primitive.center) - primitive.radius);
  }
  return Math.abs(distance(point, primitive.center) - primitive.radius);
}

function distanceToSegment(point: Vec2, start: Vec2, end: Vec2) {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const lengthSquared = dx * dx + dy * dy;
  if (lengthSquared === 0) {
    return distance(point, start);
  }
  const t = Math.max(0, Math.min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared));
  return distance(point, { x: start.x + dx * t, y: start.y + dy * t });
}

function calculateSelectionCenter(primitives: readonly PatternPrimitive[]) {
  const bounds = primitives.length > 0 ? calculateDesignPatternBounds({ id: 'selection', name: 'selection', primitives }) : undefined;
  return bounds?.center ?? { x: 0, y: 0 };
}

function pointOnCircle(center: Vec2, radius: number, angleDeg: number): Vec2 {
  const radians = (angleDeg * Math.PI) / 180;
  return { x: center.x + Math.cos(radians) * radius, y: center.y + Math.sin(radians) * radius };
}

function distance(a: Vec2, b: Vec2) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function angleDeg(a: Vec2, b: Vec2) {
  return (Math.atan2(b.y - a.y, b.x - a.x) * 180) / Math.PI;
}

function toggleId(ids: readonly string[], id: string) {
  return ids.includes(id) ? ids.filter((item) => item !== id) : [...ids, id];
}

function toolLabel(tool: DesignerTool) {
  return tool === 'select' ? 'Select' : tool[0].toUpperCase() + tool.slice(1);
}

function isShapeTool(tool: DesignerTool): tool is Exclude<DesignerTool, 'select' | 'line'> {
  return tool !== 'select' && tool !== 'line';
}

function isRegularShapeTool(tool: DesignerTool): tool is 'triangle' | 'pentagon' | 'hexagon' {
  return tool === 'triangle' || tool === 'pentagon' || tool === 'hexagon';
}

function createShapePrimitive(
  tool: Exclude<DesignerTool, 'select' | 'line'>,
  center: Vec2,
  sizePoint: Vec2,
  role: PrimitiveRole,
  rotationDeg?: number,
): PatternPrimitive {
  if (tool === 'rectangle') {
    return createCenteredRectanglePrimitive(center, sizePoint, rotationDeg ?? 0, role);
  }
  const sides = tool === 'triangle' ? 3 : tool === 'pentagon' ? 5 : 6;
  return createRegularPolygonPrimitive({
    sides,
    radius: distance(center, sizePoint),
    rotationDeg: rotationDeg ?? -90,
    center,
    role,
  });
}

function snapAngle(angle: number, step: number) {
  return Math.round(angle / step) * step;
}

function chooseVisibleGridSpacing(baseSpacing: number, zoom: number) {
  let spacing = baseSpacing;
  while (spacing * zoom < 18) {
    spacing *= 2;
  }
  while (spacing * zoom > 96 && spacing / 2 >= baseSpacing) {
    spacing /= 2;
  }
  return spacing;
}

function isMajorGridLine(value: number, baseSpacing: number) {
  const majorSpacing = baseSpacing * 5;
  return Math.abs(value / majorSpacing - Math.round(value / majorSpacing)) < 1e-8;
}
