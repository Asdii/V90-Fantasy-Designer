import { useEffect, useMemo, useState } from 'react';
import type { FacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import {
  calculateCutHelperPatternOffset,
  calculateCutHelperStageRotation,
  type CutHelperDirection,
  type CutInstruction,
} from '../grooves';

export interface CutHelperStep {
  readonly operationId: string;
  readonly operationNumber: number;
  readonly facetId: number;
  readonly localGeometry: FacetLocalGeometry;
  readonly instruction: CutInstruction;
  readonly grooveWidthMm: number;
}

interface CutHelperDialogProps {
  readonly steps: readonly CutHelperStep[];
  readonly onClose: () => void;
}

export function CutHelperDialog({ steps, onClose }: CutHelperDialogProps) {
  const [stepIndex, setStepIndex] = useState(0);
  const [orientationDeg, setOrientationDeg] = useState(0);
  const [cutDirection, setCutDirection] = useState<CutHelperDirection>('horizontal');
  const activeIndex = Math.min(stepIndex, Math.max(0, steps.length - 1));
  const activeStep = steps[activeIndex];
  const instruction = activeStep?.instruction;
  const viewport = useMemo(
    () => activeStep ? createViewport(activeStep.localGeometry, steps) : undefined,
    [activeStep, steps],
  );
  const wheelTicks = useMemo(() => viewport ? createAngleTicks(viewport.wheelRadius) : [], [viewport]);

  useEffect(() => {
    setStepIndex((current) => Math.min(current, Math.max(0, steps.length - 1)));
  }, [steps.length]);

  useEffect(() => {
    const frame = requestAnimationFrame(() => setOrientationDeg(instruction ? calculateCutHelperStageRotation(instruction.angleDeg) : 0));
    return () => cancelAnimationFrame(frame);
  }, [activeIndex, instruction]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      } else if (event.key === 'ArrowLeft') {
        event.preventDefault();
        setStepIndex((current) => Math.max(0, current - 1));
      } else if (event.key === 'ArrowRight') {
        event.preventDefault();
        setStepIndex((current) => Math.min(steps.length - 1, current + 1));
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [steps.length, onClose]);

  const completedSteps = activeStep ? steps.slice(0, activeIndex) : [];

  return (
    <div
      className="cutHelperBackdrop"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) {
          onClose();
        }
      }}
    >
      <section className="cutHelperDialog" role="dialog" aria-modal="true" aria-labelledby="cut-helper-title">
        <header className="cutHelperHeader">
          <div>
            <h2 id="cut-helper-title">Cut Helper</h2>
            <p>{activeStep ? `Operation ${activeStep.operationNumber} · Reference facet ${activeStep.facetId}` : 'Completed cutting sequence'}</p>
          </div>
          <div className="cutHelperHeaderActions">
            <div className="cutHelperDirection" role="group" aria-label="Cut direction">
              <button className={cutDirection === 'horizontal' ? 'toolbarButton active' : 'toolbarButton'} onClick={() => setCutDirection('horizontal')}>Horizontal →</button>
              <button className={cutDirection === 'vertical' ? 'toolbarButton active' : 'toolbarButton'} onClick={() => setCutDirection('vertical')}>Vertical ↑</button>
            </div>
            <button className="toolbarButton" disabled={!instruction} onClick={() => setOrientationDeg(instruction ? calculateCutHelperStageRotation(instruction.angleDeg) : 0)}>Orient to cut</button>
            <button className="toolbarButton" onClick={() => setOrientationDeg(0)}>Return to 0°</button>
            <button className="toolbarButton" onClick={onClose} aria-label="Close Cut Helper">Close</button>
          </div>
        </header>

        <div className="cutHelperViewport">
          {instruction && activeStep && viewport ? (
            <svg viewBox={viewport.viewBox} preserveAspectRatio="xMidYMid meet" aria-label={`Cut ${instruction.step} preview`}>
              <defs>
                <marker id="cut-helper-arrow" markerWidth={viewport.hairline * 8} markerHeight={viewport.hairline * 8} refX="5.5" refY="3.5" orient="auto" markerUnits="userSpaceOnUse" viewBox="0 0 7 7">
                  <path d="M0,0 L7,3.5 L0,7 Z" fill="#101820" />
                </marker>
                <marker id="cut-helper-completed-arrow" markerWidth={viewport.hairline * 5} markerHeight={viewport.hairline * 5} refX="5" refY="3" orient="auto" markerUnits="userSpaceOnUse" viewBox="0 0 6 6">
                  <path d="M0,0 L6,3 L0,6 Z" fill="#347b98" />
                </marker>
              </defs>
              <rect x={viewport.x} y={viewport.y} width={viewport.width} height={viewport.height} fill="#f7f9fb" />
              <g className="cutHelperRotatingStage" style={{ transform: `rotate(${orientationDeg}deg)` }}>
                <circle cx="0" cy="0" r={viewport.wheelRadius} className="cutHelperWheel" />
                {wheelTicks.map((tick) => (
                  <line key={`tick-${tick.angle}`} x1={tick.x1} y1={tick.y1} x2={tick.x2} y2={tick.y2} className={tick.major ? 'cutHelperWheelTick major' : 'cutHelperWheelTick'} />
                ))}
                {wheelTicks.filter((tick) => tick.label).map((tick) => (
                  <text
                    key={`label-${tick.angle}`}
                    x={tick.labelX}
                    y={tick.labelY}
                    className="cutHelperWheelLabel"
                    style={{ fontSize: viewport.wheelRadius * 0.075 }}
                  >
                    {tick.angle}°
                  </text>
                ))}
                <line x1={viewport.x} y1="0" x2={viewport.x + viewport.width} y2="0" className="cutHelperAxis cutHelperAxisX" />
                <line x1="0" y1={viewport.y} x2="0" y2={viewport.y + viewport.height} className="cutHelperAxis cutHelperAxisY" />
                <polygon points={activeStep.localGeometry.boundary.map((point) => `${point.u},${-point.v}`).join(' ')} className="cutHelperFacet" />

                <g
                  className="cutHelperPatternStage"
                  style={{ transform: `rotate(${calculateCutHelperPatternOffset(cutDirection)}deg)` }}
                >
                  {completedSteps.flatMap((completed) => completed.instruction.visibleSegments.map((segment) => (
                    <line
                      key={`completed-${completed.operationId}-${completed.instruction.step}-${segment.id}`}
                      x1={segment.start.u} y1={-segment.start.v}
                      x2={segment.end.u} y2={-segment.end.v}
                      className="cutHelperCompletedCut"
                      style={{ strokeWidth: viewport.hairline * 1.25 }}
                      markerEnd="url(#cut-helper-completed-arrow)"
                    />
                  )))}

                  {instruction.visibleSegments.map((segment) => (
                    <g key={`active-${segment.id}`}>
                      <line x1={segment.start.u} y1={-segment.start.v} x2={segment.end.u} y2={-segment.end.v} className="cutHelperActiveOpening" style={{ strokeWidth: Math.max(activeStep.grooveWidthMm, viewport.hairline * 3) }} />
                      <line x1={segment.start.u} y1={-segment.start.v} x2={segment.end.u} y2={-segment.end.v} className="cutHelperActiveCenter" style={{ strokeWidth: viewport.hairline }} markerEnd="url(#cut-helper-arrow)" />
                    </g>
                  ))}
                </g>
                <circle cx="0" cy="0" r={viewport.hairline * 2.4} className="cutHelperOrigin" />
              </g>
              <path
                d={`M ${-viewport.wheelRadius * 0.035} ${viewport.wheelRadius * 1.08} L 0 ${viewport.wheelRadius * 0.99} L ${viewport.wheelRadius * 0.035} ${viewport.wheelRadius * 1.08} Z`}
                className="cutHelperIndexMarker"
              />
            </svg>
          ) : (
            <p className="cutHelperEmpty">There are no pattern cuts on this facet.</p>
          )}
        </div>

        <footer className="cutHelperFooter">
          <button className="toolbarButton" disabled={activeIndex <= 0} onClick={() => setStepIndex((current) => Math.max(0, current - 1))}>
            Previous
          </button>
          <div className="cutHelperMetrics" aria-live="polite">
            <Metric label="Step" value={instruction ? `${activeIndex + 1} / ${steps.length}` : `0 / ${steps.length}`} />
            <Metric label="Cut angle" value={instruction ? `${formatAngle(instruction.angleDeg)}°` : '—'} />
            <Metric label="Distance from center" value={instruction ? `${instruction.distanceFromCenterMm.toFixed(3)} mm` : '—'} />
            <Metric label="Depth" value={instruction ? `${instruction.depthMm.toFixed(3)} mm` : '—'} />
          </div>
          <button
            className="toolbarButton"
            disabled={!instruction || activeIndex >= steps.length - 1}
            onClick={() => setStepIndex((current) => Math.min(steps.length - 1, current + 1))}
          >
            Next
          </button>
        </footer>
      </section>
    </div>
  );
}

function Metric({ label, value }: { readonly label: string; readonly value: string }) {
  return (
    <div className="cutHelperMetric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function createViewport(localGeometry: FacetLocalGeometry, steps: readonly CutHelperStep[]) {
  const diagonal = Math.max(Math.hypot(localGeometry.bounds.width, localGeometry.bounds.height), 0.5);
  const facetRadius = Math.max(...localGeometry.boundary.map((point) => Math.hypot(point.u, point.v)), diagonal / 2);
  const cutRadius = steps.reduce((maximum, step) => {
    const visibleSegments = step.instruction.visibleSegments.length > 0
      ? step.instruction.visibleSegments
      : [step.instruction.segment];
    return visibleSegments.reduce((segmentMaximum, segment) => Math.max(
      segmentMaximum,
      Math.hypot(segment.start.u, segment.start.v),
      Math.hypot(segment.end.u, segment.end.v),
    ), maximum);
  }, 0);
  const widestGroove = steps.reduce((maximum, step) => Math.max(maximum, step.grooveWidthMm), 0);
  const contentRadius = Math.max(facetRadius, cutRadius);
  const wheelRadius = Math.max(contentRadius * 1.18, contentRadius + widestGroove * 3, 0.5);
  const extent = wheelRadius * 1.2;
  const x = -extent;
  const y = -extent;
  const width = extent * 2;
  const height = extent * 2;
  return {
    x,
    y,
    width,
    height,
    wheelRadius,
    hairline: Math.max(diagonal * 0.0025, 0.01),
    viewBox: `${x} ${y} ${width} ${height}`,
  };
}

function createAngleTicks(radius: number) {
  return Array.from({ length: 72 }, (_, index) => {
    const angle = index * 5;
    const radians = (angle * Math.PI) / 180;
    const major = angle % 30 === 0;
    const medium = angle % 10 === 0;
    const length = radius * (major ? 0.09 : medium ? 0.06 : 0.035);
    const inner = radius - length;
    const labelRadius = radius * 0.84;
    return {
      angle,
      major,
      label: major,
      x1: Math.sin(radians) * inner,
      y1: Math.cos(radians) * inner,
      x2: Math.sin(radians) * radius,
      y2: Math.cos(radians) * radius,
      labelX: Math.sin(radians) * labelRadius,
      labelY: Math.cos(radians) * labelRadius,
    };
  });
}

function formatAngle(value: number) {
  const rounded = Math.round(value * 10) / 10;
  return Number.isInteger(rounded) ? rounded.toFixed(0) : rounded.toFixed(1);
}
