import { useEffect, useMemo, useRef, useState } from 'react';
import {
  calculateMeasuredLengthMm,
  MEASUREMENT_PIXELS_PER_MM,
  type MeasurementPoint,
  type MeasurementSpan,
} from '../geometry/FacetMeasurement';
import {
  createPatternReferenceImage,
  type PatternReferenceImage,
} from '../patterns/editor/PatternReferenceImage';

export interface FacetMeasurementResult {
  readonly measuredLengthMm: number;
  readonly referenceImage: PatternReferenceImage;
}

interface FacetMeasurementDialogProps {
  readonly facetId: number;
  readonly modelFacetLengthMm: number;
  readonly facetGuide: FacetMeasurementGuide;
  readonly statusMessage?: string;
  readonly onApply: (result: FacetMeasurementResult) => void;
  readonly onClose: () => void;
}

export interface FacetMeasurementGuide {
  readonly boundary: readonly MeasurementPoint[];
  readonly maximumSpan: MeasurementSpan;
}

type MeasurementTool = 'move' | 'circle' | 'measure';
type MeasurementDrag =
  | { readonly type: 'image'; readonly pointerId: number; readonly x: number; readonly y: number; readonly panX: number; readonly panY: number }
  | { readonly type: 'circle'; readonly pointerId: number; readonly x: number; readonly y: number; readonly centerX: number; readonly centerY: number };

export function FacetMeasurementDialog({
  facetId,
  modelFacetLengthMm,
  facetGuide,
  statusMessage,
  onApply,
  onClose,
}: FacetMeasurementDialogProps) {
  const viewportRef = useRef<HTMLDivElement>(null);
  const dragRef = useRef<MeasurementDrag | undefined>(undefined);
  const [imageUrl, setImageUrl] = useState<string>();
  const [imageSize, setImageSize] = useState<{ width: number; height: number }>();
  const [imageZoom, setImageZoom] = useState(1);
  const [imagePan, setImagePan] = useState({ x: 0, y: 0 });
  const [referenceDiameterMm, setReferenceDiameterMm] = useState(10);
  const [referenceCenter, setReferenceCenter] = useState<MeasurementPoint>();
  const [tool, setTool] = useState<MeasurementTool>('move');
  const [points, setPoints] = useState<MeasurementPoint[]>([]);
  const referenceDiameterPx = referenceDiameterMm * MEASUREMENT_PIXELS_PER_MM;

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  const measuredLengthMm = useMemo(() => {
    if (points.length !== 2) {
      return undefined;
    }
    return calculateMeasuredLengthMm(points[0], points[1], referenceDiameterMm, referenceDiameterPx);
  }, [points, referenceDiameterMm, referenceDiameterPx]);

  const handleImage = (file?: File) => {
    if (!file) {
      return;
    }
    const reader = new FileReader();
    reader.addEventListener('load', () => {
      if (typeof reader.result !== 'string') {
        return;
      }
      setImageUrl(reader.result);
      setImageSize(undefined);
      setImageZoom(1);
      setImagePan({ x: 0, y: 0 });
      setReferenceCenter(undefined);
      setPoints([]);
    });
    reader.readAsDataURL(file);
  };

  const applyMeasurement = () => {
    const rect = viewportRef.current?.getBoundingClientRect();
    if (!measuredLengthMm || !imageUrl || !imageSize || !rect || rect.width <= 0 || rect.height <= 0) {
      return;
    }
    const circleCenter = referenceCenter ?? { x: rect.width / 2, y: rect.height / 2 };
    const imageCenter = { x: rect.width / 2 + imagePan.x, y: rect.height / 2 + imagePan.y };
    onApply({
      measuredLengthMm,
      referenceImage: createPatternReferenceImage({
        dataUrl: imageUrl,
        naturalWidth: imageSize.width,
        naturalHeight: imageSize.height,
        viewportWidth: rect.width,
        viewportHeight: rect.height,
        imageZoom,
        imagePan: { x: imageCenter.x - circleCenter.x, y: imageCenter.y - circleCenter.y },
        referenceDiameterMm,
        referenceDiameterPx,
      }),
    });
  };

  const localPoint = (clientX: number, clientY: number): MeasurementPoint | undefined => {
    const rect = viewportRef.current?.getBoundingClientRect();
    return rect ? { x: clientX - rect.left, y: clientY - rect.top } : undefined;
  };

  return (
    <div className="cutHelperBackdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section className="measurementDialog" role="dialog" aria-modal="true" aria-labelledby="measurement-title">
        <header className="cutHelperHeader">
          <div>
            <h2 id="measurement-title">Measure Facet</h2>
            <p>Facet {facetId} · maximum span {modelFacetLengthMm.toFixed(3)} mm</p>
          </div>
          <button className="toolbarButton" onClick={onClose}>Close</button>
        </header>

        <div className="measurementBody">
          <div
            ref={viewportRef}
            className={`measurementViewport measurementTool-${tool}`}
            onPointerDown={(event) => {
              const point = localPoint(event.clientX, event.clientY);
              if (!point) {
                return;
              }
              if (tool === 'measure') {
                setPoints((current) => current.length >= 2 ? [point] : [...current, point]);
                return;
              }
              event.currentTarget.setPointerCapture(event.pointerId);
              if (tool === 'circle') {
                const rect = event.currentTarget.getBoundingClientRect();
                const center = referenceCenter ?? { x: rect.width / 2, y: rect.height / 2 };
                dragRef.current = { type: 'circle', pointerId: event.pointerId, x: event.clientX, y: event.clientY, centerX: center.x, centerY: center.y };
              } else {
                dragRef.current = { type: 'image', pointerId: event.pointerId, x: event.clientX, y: event.clientY, panX: imagePan.x, panY: imagePan.y };
              }
            }}
            onPointerMove={(event) => {
              const drag = dragRef.current;
              if (!drag || drag.pointerId !== event.pointerId) {
                return;
              }
              if (drag.type === 'circle') {
                setReferenceCenter({
                  x: drag.centerX + event.clientX - drag.x,
                  y: drag.centerY + event.clientY - drag.y,
                });
              } else {
                setImagePan({
                  x: drag.panX + event.clientX - drag.x,
                  y: drag.panY + event.clientY - drag.y,
                });
              }
            }}
            onPointerUp={(event) => {
              if (dragRef.current?.pointerId === event.pointerId) {
                dragRef.current = undefined;
                event.currentTarget.releasePointerCapture(event.pointerId);
              }
            }}
          >
            {imageUrl ? (
              <img
                src={imageUrl}
                alt="Measurement reference"
                draggable={false}
                onLoad={(event) => setImageSize({ width: event.currentTarget.naturalWidth, height: event.currentTarget.naturalHeight })}
                style={{ transform: `translate(${imagePan.x}px, ${imagePan.y}px) scale(${imageZoom})` }}
              />
            ) : (
              <div className="measurementPlaceholder">Load a photograph containing a circular reference.</div>
            )}
            <svg className="measurementOverlay" aria-label="Reference circle and facet measurement">
              <circle cx={referenceCenter?.x ?? '50%'} cy={referenceCenter?.y ?? '50%'} r={referenceDiameterPx / 2} className="measurementReferenceCircle" />
              {points.length === 2 ? (
                <line x1={points[0].x} y1={points[0].y} x2={points[1].x} y2={points[1].y} className="measurementLine" />
              ) : null}
              {points.map((point, index) => <circle key={index} cx={point.x} cy={point.y} r="5" className="measurementPoint" />)}
            </svg>
          </div>

          <aside className="measurementControls">
            <FacetSpanGuide guide={facetGuide} />
            <label className="fileButton toolbarButton measurementFileButton">
              Load photo
              <input type="file" accept="image/*" onChange={(event) => handleImage(event.target.files?.[0])} />
            </label>
            <div className="patternControls" role="group" aria-label="Measurement tool">
              <button className={tool === 'move' ? 'toolbarButton active' : 'toolbarButton'} onClick={() => setTool('move')}>Move photo</button>
              <button className={tool === 'circle' ? 'toolbarButton active' : 'toolbarButton'} onClick={() => setTool('circle')}>Move circle</button>
              <button className={tool === 'measure' ? 'toolbarButton active' : 'toolbarButton'} disabled={!imageUrl} onClick={() => setTool('measure')}>Measure</button>
            </div>
            <RangeControl label="Photo scale" value={imageZoom} min={0.2} max={5} step={0.01} onChange={setImageZoom} />
            <RangeControl label="Virtual circle diameter" value={referenceDiameterMm} min={1} max={30} step={0.1} suffix="mm" onChange={setReferenceDiameterMm} />
            <p className="measurementHint">Match the virtual circle to the photo reference. Then choose Measure and mark the two ends of the highlighted maximum facet span.</p>
            <dl className="measurementResult">
              <dt>Measured maximum span</dt>
              <dd>{measuredLengthMm ? `${measuredLengthMm.toFixed(3)} mm` : 'Select two points'}</dd>
              <dt>Model maximum span</dt>
              <dd>{modelFacetLengthMm.toFixed(3)} mm</dd>
              <dt>Scale factor</dt>
              <dd>{measuredLengthMm ? (measuredLengthMm / modelFacetLengthMm).toFixed(6) : '—'}</dd>
            </dl>
            {statusMessage ? <p className="measurementNotice" role="status">{statusMessage}</p> : null}
            <div className="measurementActions">
              <button className="toolbarButton" disabled={points.length === 0} onClick={() => setPoints([])}>Clear points</button>
              <button
                className="toolbarButton active"
                disabled={!measuredLengthMm || measuredLengthMm <= 0 || !imageSize}
                onClick={applyMeasurement}
              >
                Scale STL
              </button>
            </div>
          </aside>
        </div>
      </section>
    </div>
  );
}

function FacetSpanGuide({ guide }: { readonly guide: FacetMeasurementGuide }) {
  const bounds = guide.boundary.reduce((result, point) => ({
    minX: Math.min(result.minX, point.x),
    maxX: Math.max(result.maxX, point.x),
    minY: Math.min(result.minY, point.y),
    maxY: Math.max(result.maxY, point.y),
  }), { minX: Infinity, maxX: -Infinity, minY: Infinity, maxY: -Infinity });
  const width = Math.max(bounds.maxX - bounds.minX, 0.001);
  const height = Math.max(bounds.maxY - bounds.minY, 0.001);
  const padding = Math.max(width, height) * 0.16;
  const viewBox = `${bounds.minX - padding} ${-bounds.maxY - padding} ${width + padding * 2} ${height + padding * 2}`;

  return (
    <section className="measurementFacetGuide" aria-label="Longest facet span guide">
      <div>
        <strong>Measure this span</strong>
        <span>{guide.maximumSpan.lengthMm.toFixed(3)} mm in the current model</span>
      </div>
      <svg viewBox={viewBox} preserveAspectRatio="xMidYMid meet" role="img" aria-label="Selected facet with its longest span highlighted">
        <polygon points={guide.boundary.map((point) => `${point.x},${-point.y}`).join(' ')} />
        <line
          x1={guide.maximumSpan.start.x}
          y1={-guide.maximumSpan.start.y}
          x2={guide.maximumSpan.end.x}
          y2={-guide.maximumSpan.end.y}
        />
        <circle cx={guide.maximumSpan.start.x} cy={-guide.maximumSpan.start.y} r={Math.max(width, height) * 0.025} />
        <circle cx={guide.maximumSpan.end.x} cy={-guide.maximumSpan.end.y} r={Math.max(width, height) * 0.025} />
      </svg>
    </section>
  );
}

function RangeControl({ label, value, min, max, step, suffix, onChange }: {
  readonly label: string;
  readonly value: number;
  readonly min: number;
  readonly max: number;
  readonly step: number;
  readonly suffix?: string;
  readonly onChange: (value: number) => void;
}) {
  return (
    <label className="measurementControl">
      <span>{label}</span>
      <input type="range" value={value} min={min} max={max} step={step} onChange={(event) => onChange(Number(event.target.value))} />
      <output>{value.toFixed(step < 1 ? 2 : 0)} {suffix}</output>
    </label>
  );
}
