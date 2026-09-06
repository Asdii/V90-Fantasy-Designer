import { useState } from 'react';
import type { GridSnapStep, Pattern, PatternTool } from '../patterns/Pattern';
import { calculatePatternBounds, replaceSegment, segmentAngleDegrees, segmentLength } from '../patterns/PatternGeometry';
import type { GeneratorType } from '../patterns/PatternGenerators';

interface PatternPanelProps {
  readonly activeTool: PatternTool;
  readonly canRedo: boolean;
  readonly canUndo: boolean;
  readonly generatorMode: 'replace' | 'add';
  readonly generatorParams: Record<string, number>;
  readonly generatorPreview?: Pattern;
  readonly generatorType: GeneratorType;
  readonly gridSnap: GridSnapStep;
  readonly pattern?: Pattern;
  readonly radialSymmetryEnabled: boolean;
  readonly radialSymmetryOrder: number;
  readonly selectedSegmentId?: string;
  readonly showOutsideFacet: boolean;
  readonly snapEnabled: boolean;
  readonly onActiveToolChange: (tool: PatternTool) => void;
  readonly onApplyGeneratedPattern: () => void;
  readonly onClearPattern: () => void;
  readonly onCircularArray: (
    copies: number,
    totalAngleDeg: number,
    center: { readonly u: number; readonly v: number },
    startAngleDeg: number,
  ) => void;
  readonly onFitPatternToFacet: () => void;
  readonly onGeneratorModeChange: (mode: 'replace' | 'add') => void;
  readonly onGeneratorParamsChange: (params: Record<string, number>) => void;
  readonly onGeneratorTypeChange: (type: GeneratorType) => void;
  readonly onGridSnapChange: (step: GridSnapStep) => void;
  readonly onMirror: (axis: 'u' | 'v') => void;
  readonly onPatternChange: (pattern: Pattern) => void;
  readonly onPatternTransformChange: (partial: Partial<Pattern['transform']>) => void;
  readonly onRadialSymmetryEnabledChange: (enabled: boolean) => void;
  readonly onRadialSymmetryOrderChange: (order: number) => void;
  readonly onRedo: () => void;
  readonly onSelectedSegmentChange: (segmentId: string | undefined) => void;
  readonly onShowOutsideFacetChange: (enabled: boolean) => void;
  readonly onSnapEnabledChange: (enabled: boolean) => void;
  readonly onUndo: () => void;
}

const tools: PatternTool[] = ['select', 'line', 'polyline', 'polygon', 'rectangle', 'circle'];

export function PatternPanel({
  activeTool,
  canRedo,
  canUndo,
  generatorMode,
  generatorParams,
  generatorPreview,
  generatorType,
  gridSnap,
  pattern,
  radialSymmetryEnabled,
  radialSymmetryOrder,
  selectedSegmentId,
  showOutsideFacet,
  snapEnabled,
  onActiveToolChange,
  onApplyGeneratedPattern,
  onClearPattern,
  onCircularArray,
  onFitPatternToFacet,
  onGeneratorModeChange,
  onGeneratorParamsChange,
  onGeneratorTypeChange,
  onGridSnapChange,
  onMirror,
  onPatternChange,
  onPatternTransformChange,
  onRadialSymmetryEnabledChange,
  onRadialSymmetryOrderChange,
  onRedo,
  onSelectedSegmentChange,
  onShowOutsideFacetChange,
  onSnapEnabledChange,
  onUndo,
}: PatternPanelProps) {
  const [arrayCopies, setArrayCopies] = useState(8);
  const [arrayCenterU, setArrayCenterU] = useState(0);
  const [arrayCenterV, setArrayCenterV] = useState(0);
  const [arrayTotalAngle, setArrayTotalAngle] = useState(360);
  const [arrayStartAngle, setArrayStartAngle] = useState(0);
  const [duplicateCopies, setDuplicateCopies] = useState(6);
  const [duplicateStep, setDuplicateStep] = useState(30);
  const bounds = calculatePatternBounds(pattern);
  const selectedSegment = pattern?.segments.find((segment) => segment.id === selectedSegmentId);

  return (
    <section className="patternPanel">
      <h2>Pattern</h2>
      <div className="toolGrid">
        {tools.map((tool) => (
          <button
            key={tool}
            className={activeTool === tool ? 'toolbarButton active' : 'toolbarButton'}
            onClick={() => onActiveToolChange(tool)}
          >
            {toolLabel(tool)}
          </button>
        ))}
      </div>
      <div className="patternControls">
        <label className="wireframeToggle">
          <input
            type="checkbox"
            checked={snapEnabled}
            onChange={(event) => onSnapEnabledChange(event.target.checked)}
          />
          Snap
        </label>
        <label>
          Grid
          <select
            className="toolbarSelect"
            value={gridSnap}
            onChange={(event) => onGridSnapChange(event.target.value as GridSnapStep)}
          >
            <option value="off">Off</option>
            <option value="1">1.0 mm</option>
            <option value="0.5">0.5 mm</option>
            <option value="0.1">0.1 mm</option>
          </select>
        </label>
      </div>
      <div className="patternControls">
        <label className="wireframeToggle">
          <input
            type="checkbox"
            checked={radialSymmetryEnabled}
            onChange={(event) => onRadialSymmetryEnabledChange(event.target.checked)}
          />
          Radial symmetry
        </label>
        <NumberInput label="Order" value={radialSymmetryOrder} min={2} max={32} step={1} onChange={onRadialSymmetryOrderChange} />
      </div>
      <div className="patternControls">
        <button className="toolbarButton" disabled={!canUndo} onClick={onUndo}>
          Undo
        </button>
        <button className="toolbarButton" disabled={!canRedo} onClick={onRedo}>
          Redo
        </button>
        <button className="toolbarButton" onClick={onClearPattern}>
          Clear Pattern
        </button>
      </div>
      <dl>
        <dt>Segments</dt>
        <dd>{pattern?.segments.length ?? 0}</dd>
        <dt>Pattern size</dt>
        <dd>
          {bounds.width.toFixed(3)} x {bounds.height.toFixed(3)} mm
        </dd>
      </dl>
      <h3>Generate</h3>
      <div className="patternControls stacked">
        <label>
          Generator
          <select
            className="toolbarSelect"
            value={generatorType}
            onChange={(event) => onGeneratorTypeChange(event.target.value as GeneratorType)}
          >
            <option value="regularPolygon">Regular polygon</option>
            <option value="star">Star</option>
            <option value="starPolygon">Star polygon</option>
            <option value="radialLines">Radial lines</option>
            <option value="concentricPolygons">Concentric polygons</option>
            <option value="concentricCircles">Concentric circles</option>
            <option value="simpleRosette">Simple rosette</option>
          </select>
        </label>
        <GeneratorFields generatorType={generatorType} params={generatorParams} onChange={onGeneratorParamsChange} />
        <label>
          Mode
          <select
            className="toolbarSelect"
            value={generatorMode}
            onChange={(event) => onGeneratorModeChange(event.target.value as 'replace' | 'add')}
          >
            <option value="replace">Replace Pattern</option>
            <option value="add">Add to Pattern</option>
          </select>
        </label>
        <div className="patternControls">
          <button className="toolbarButton" onClick={onApplyGeneratedPattern}>
            Create
          </button>
          <button
            className="toolbarButton"
            onClick={() => onGeneratorParamsChange({ ...generatorParams, points: 8, outerRadius: 3, innerRadius: 1.4, rotationDeg: 0 })}
          >
            8-point star
          </button>
          <button
            className="toolbarButton"
            onClick={() => onGeneratorParamsChange({ ...generatorParams, count: 12, innerRadius: 0, outerRadius: 3, rotationDeg: 0 })}
          >
            12 radial
          </button>
        </div>
        <p>Preview: {generatorPreview?.segments.length ?? 0} segments</p>
      </div>
      <h3>Transform</h3>
      <div className="coordinateEditor">
        <NumberInput label="Position U" value={pattern?.transform.offsetU ?? 0} step={0.001} onChange={(value) => onPatternTransformChange({ offsetU: value })} />
        <NumberInput label="Position V" value={pattern?.transform.offsetV ?? 0} step={0.001} onChange={(value) => onPatternTransformChange({ offsetV: value })} />
        <NumberInput label="Rotation" value={pattern?.transform.rotationDeg ?? 0} step={1} onChange={(value) => onPatternTransformChange({ rotationDeg: value })} />
        <NumberInput label="Scale" value={pattern?.transform.scale ?? 1} min={0.001} step={0.01} onChange={(value) => onPatternTransformChange({ scale: value })} />
        <button className="toolbarButton" onClick={onFitPatternToFacet}>
          Fit to facet
        </button>
      </div>
      <h3>Operations</h3>
      <div className="patternControls">
        <button className="toolbarButton" onClick={() => onMirror('u')}>
          Mirror U
        </button>
        <button className="toolbarButton" onClick={() => onMirror('v')}>
          Mirror V
        </button>
      </div>
      <div className="coordinateEditor">
        <NumberInput label="Copies" value={arrayCopies} min={1} step={1} onChange={setArrayCopies} />
        <NumberInput label="Center U" value={arrayCenterU} step={0.001} onChange={setArrayCenterU} />
        <NumberInput label="Center V" value={arrayCenterV} step={0.001} onChange={setArrayCenterV} />
        <NumberInput label="Total angle" value={arrayTotalAngle} step={1} onChange={setArrayTotalAngle} />
        <NumberInput label="Start angle" value={arrayStartAngle} step={1} onChange={setArrayStartAngle} />
        <button
          className="toolbarButton"
          onClick={() => onCircularArray(arrayCopies, arrayTotalAngle, { u: arrayCenterU, v: arrayCenterV }, arrayStartAngle)}
        >
          Circular Array
        </button>
      </div>
      <div className="coordinateEditor">
        <NumberInput label="Duplicate copies" value={duplicateCopies} min={1} step={1} onChange={setDuplicateCopies} />
        <NumberInput label="Step" value={duplicateStep} step={1} onChange={setDuplicateStep} />
        <button
          className="toolbarButton"
          onClick={() => onCircularArray(duplicateCopies + 1, duplicateStep * (duplicateCopies + 1), { u: 0, v: 0 }, 0)}
        >
          Duplicate rotated
        </button>
      </div>
      <h3>View</h3>
      <label className="wireframeToggle">
        <input
          type="checkbox"
          checked={showOutsideFacet}
          onChange={(event) => onShowOutsideFacetChange(event.target.checked)}
        />
        Show outside facet
      </label>
      {selectedSegment ? (
        <>
          <h3>Selected line</h3>
          <dl>
            <dt>Length</dt>
            <dd>{segmentLength(selectedSegment).toFixed(3)} mm</dd>
            <dt>Angle</dt>
            <dd>{segmentAngleDegrees(selectedSegment).toFixed(3)} deg</dd>
          </dl>
          <div className="coordinateEditor">
            <CoordinateInputs
              label="Start"
              u={selectedSegment.start.u}
              v={selectedSegment.start.v}
              onChange={(point) => onPatternChange(replaceSegment(pattern as Pattern, { ...selectedSegment, start: point }))}
            />
            <CoordinateInputs
              label="End"
              u={selectedSegment.end.u}
              v={selectedSegment.end.v}
              onChange={(point) => onPatternChange(replaceSegment(pattern as Pattern, { ...selectedSegment, end: point }))}
            />
          </div>
          <button className="toolbarButton" onClick={() => onSelectedSegmentChange(undefined)}>
            Deselect line
          </button>
        </>
      ) : (
        <p>No selected line</p>
      )}
    </section>
  );
}

function GeneratorFields({
  generatorType,
  params,
  onChange,
}: {
  readonly generatorType: GeneratorType;
  readonly params: Record<string, number>;
  readonly onChange: (params: Record<string, number>) => void;
}) {
  const setParam = (key: string, value: number) => onChange({ ...params, [key]: value });

  if (generatorType === 'regularPolygon') {
    return (
      <>
        <NumberInput label="Sides" value={params.sides} min={3} step={1} onChange={(value) => setParam('sides', value)} />
        <NumberInput label="Radius" value={params.radius} min={0} step={0.1} onChange={(value) => setParam('radius', value)} />
        <NumberInput label="Rotation" value={params.rotationDeg} step={1} onChange={(value) => setParam('rotationDeg', value)} />
      </>
    );
  }

  if (generatorType === 'star') {
    return (
      <>
        <NumberInput label="Points" value={params.points} min={2} step={1} onChange={(value) => setParam('points', value)} />
        <NumberInput label="Outer radius" value={params.outerRadius} min={0} step={0.1} onChange={(value) => setParam('outerRadius', value)} />
        <NumberInput label="Inner radius" value={params.innerRadius} min={0} step={0.1} onChange={(value) => setParam('innerRadius', value)} />
        <NumberInput label="Rotation" value={params.rotationDeg} step={1} onChange={(value) => setParam('rotationDeg', value)} />
      </>
    );
  }

  if (generatorType === 'starPolygon') {
    return (
      <>
        <NumberInput label="Points" value={params.points} min={3} step={1} onChange={(value) => setParam('points', value)} />
        <NumberInput label="Step" value={params.step} min={1} step={1} onChange={(value) => setParam('step', value)} />
        <NumberInput label="Radius" value={params.radius} min={0} step={0.1} onChange={(value) => setParam('radius', value)} />
        <NumberInput label="Rotation" value={params.rotationDeg} step={1} onChange={(value) => setParam('rotationDeg', value)} />
      </>
    );
  }

  if (generatorType === 'radialLines') {
    return (
      <>
        <NumberInput label="Count" value={params.count} min={1} step={1} onChange={(value) => setParam('count', value)} />
        <NumberInput label="Inner radius" value={params.innerRadius} min={0} step={0.1} onChange={(value) => setParam('innerRadius', value)} />
        <NumberInput label="Outer radius" value={params.outerRadius} min={0} step={0.1} onChange={(value) => setParam('outerRadius', value)} />
        <NumberInput label="Rotation" value={params.rotationDeg} step={1} onChange={(value) => setParam('rotationDeg', value)} />
      </>
    );
  }

  if (generatorType === 'concentricPolygons') {
    return (
      <>
        <NumberInput label="Sides" value={params.sides} min={3} step={1} onChange={(value) => setParam('sides', value)} />
        <NumberInput label="Count" value={params.count} min={1} step={1} onChange={(value) => setParam('count', value)} />
        <NumberInput label="Inner radius" value={params.innerRadius2} min={0} step={0.1} onChange={(value) => setParam('innerRadius2', value)} />
        <NumberInput label="Outer radius" value={params.outerRadius2} min={0} step={0.1} onChange={(value) => setParam('outerRadius2', value)} />
        <NumberInput label="Rotation" value={params.rotationDeg} step={1} onChange={(value) => setParam('rotationDeg', value)} />
      </>
    );
  }

  if (generatorType === 'concentricCircles') {
    return (
      <>
        <NumberInput label="Count" value={params.count} min={1} step={1} onChange={(value) => setParam('count', value)} />
        <NumberInput label="Inner radius" value={params.innerRadius2} min={0} step={0.1} onChange={(value) => setParam('innerRadius2', value)} />
        <NumberInput label="Outer radius" value={params.outerRadius2} min={0} step={0.1} onChange={(value) => setParam('outerRadius2', value)} />
      </>
    );
  }

  return (
    <>
      <NumberInput label="Order" value={params.order} min={3} step={1} onChange={(value) => setParam('order', value)} />
      <NumberInput label="Outer radius" value={params.outerRadius} min={0} step={0.1} onChange={(value) => setParam('outerRadius', value)} />
      <NumberInput label="Inner radius" value={params.innerRadius} min={0} step={0.1} onChange={(value) => setParam('innerRadius', value)} />
      <NumberInput label="Rotation" value={params.rotationDeg} step={1} onChange={(value) => setParam('rotationDeg', value)} />
      <NumberInput label="Connection step" value={params.connectionStep} min={1} step={1} onChange={(value) => setParam('connectionStep', value)} />
    </>
  );
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
      <input
        type="number"
        min={min}
        max={max}
        step={step ?? 0.001}
        value={Number.isFinite(value) ? value : 0}
        onChange={(event) => onChange(Number(event.target.value))}
      />
    </label>
  );
}

function CoordinateInputs({
  label,
  u,
  v,
  onChange,
}: {
  readonly label: string;
  readonly u: number;
  readonly v: number;
  readonly onChange: (point: { readonly u: number; readonly v: number }) => void;
}) {
  return (
    <fieldset>
      <legend>{label}</legend>
      <label>
        U
        <input type="number" step="0.001" value={u} onChange={(event) => onChange({ u: Number(event.target.value), v })} />
      </label>
      <label>
        V
        <input type="number" step="0.001" value={v} onChange={(event) => onChange({ u, v: Number(event.target.value) })} />
      </label>
    </fieldset>
  );
}

function toolLabel(tool: PatternTool) {
  return tool === 'select' ? 'Select' : tool[0].toUpperCase() + tool.slice(1);
}
