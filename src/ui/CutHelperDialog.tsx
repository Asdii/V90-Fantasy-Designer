import { useEffect, useMemo, useState } from 'react';
import type { FacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import type { CutInstruction } from '../grooves';

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
  const activeIndex = Math.min(stepIndex, Math.max(0, steps.length - 1));
  const activeStep = steps[activeIndex];
  const instruction = activeStep?.instruction;
  const viewport = useMemo(
    () => activeStep ? createViewport(activeStep.localGeometry, activeStep.grooveWidthMm) : undefined,
    [activeStep],
  );

  useEffect(() => {
    setStepIndex((current) => Math.min(current, Math.max(0, steps.length - 1)));
  }, [steps.length]);

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

  const completedInOperation = activeStep
    ? steps.slice(0, activeIndex).filter((step) => step.operationId === activeStep.operationId)
    : [];

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
            <p>{activeStep ? `Operation ${activeStep.operationNumber} · Facet ${activeStep.facetId}` : 'Completed cutting sequence'}</p>
          </div>
          <button className="toolbarButton" onClick={onClose} aria-label="Close Cut Helper">Close</button>
        </header>

        <div className="cutHelperViewport">
          {instruction && activeStep && viewport ? (
            <svg viewBox={viewport.viewBox} preserveAspectRatio="xMidYMid meet" aria-label={`Cut ${instruction.step} preview`}>
              <defs>
                <marker id="cut-helper-arrow" markerWidth="7" markerHeight="7" refX="5.5" refY="3.5" orient="auto" markerUnits="strokeWidth">
                  <path d="M0,0 L7,3.5 L0,7 Z" fill="#101820" />
                </marker>
              </defs>
              <rect x={viewport.x} y={viewport.y} width={viewport.width} height={viewport.height} fill="#f7f9fb" />
              <line x1={viewport.x} y1="0" x2={viewport.x + viewport.width} y2="0" className="cutHelperAxis cutHelperAxisX" />
              <line x1="0" y1={viewport.y} x2="0" y2={viewport.y + viewport.height} className="cutHelperAxis cutHelperAxisY" />
              <polygon points={activeStep.localGeometry.boundary.map((point) => `${point.u},${-point.v}`).join(' ')} className="cutHelperFacet" />

              {completedInOperation.flatMap((completed) => completed.instruction.visibleSegments.map((segment) => (
                <line
                  key={`completed-${completed.operationId}-${completed.instruction.step}-${segment.id}`}
                  x1={segment.start.u}
                  y1={-segment.start.v}
                  x2={segment.end.u}
                  y2={-segment.end.v}
                  className="cutHelperCompletedCut"
                  style={{ strokeWidth: Math.max(completed.grooveWidthMm, viewport.hairline * 2) }}
                />
              )))}

              {instruction.visibleSegments.map((segment) => (
                <g key={`active-${segment.id}`}>
                  <line
                    x1={segment.start.u}
                    y1={-segment.start.v}
                    x2={segment.end.u}
                    y2={-segment.end.v}
                    className="cutHelperActiveOpening"
                    style={{ strokeWidth: Math.max(activeStep.grooveWidthMm, viewport.hairline * 3) }}
                  />
                  <line
                    x1={segment.start.u}
                    y1={-segment.start.v}
                    x2={segment.end.u}
                    y2={-segment.end.v}
                    className="cutHelperActiveCenter"
                    style={{ strokeWidth: viewport.hairline }}
                    markerEnd="url(#cut-helper-arrow)"
                  />
                </g>
              ))}
              <circle cx="0" cy="0" r={viewport.hairline * 2.4} className="cutHelperOrigin" />
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

function createViewport(localGeometry: FacetLocalGeometry, grooveWidthMm: number) {
  const diagonal = Math.hypot(localGeometry.bounds.width, localGeometry.bounds.height);
  const padding = Math.max(diagonal * 0.08, grooveWidthMm * 2, 0.25);
  const x = localGeometry.bounds.minU - padding;
  const y = -localGeometry.bounds.maxV - padding;
  const width = localGeometry.bounds.width + padding * 2;
  const height = localGeometry.bounds.height + padding * 2;
  return {
    x,
    y,
    width,
    height,
    hairline: Math.max(diagonal * 0.0025, 0.01),
    viewBox: `${x} ${y} ${width} ${height}`,
  };
}

function formatAngle(value: number) {
  const rounded = Math.round(value * 10) / 10;
  return Number.isInteger(rounded) ? rounded.toFixed(0) : rounded.toFixed(1);
}
