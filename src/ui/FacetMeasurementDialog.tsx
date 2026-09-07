import { useEffect, useMemo, useRef, useState } from 'react';
import { calculateMeasuredLengthMm, type MeasurementPoint } from '../geometry/FacetMeasurement';
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
  readonly onApply: (result: FacetMeasurementResult) => void;
  readonly onClose: () => void;
}

type MeasurementTool = 'move' | 'measure';

export function FacetMeasurementDialog({
  facetId,
  modelFacetLengthMm,
  onApply,
  onClose,
}: FacetMeasurementDialogProps) {
  const viewportRef = useRef<HTMLDivElement>(null);
  const dragRef = useRef<{ pointerId: number; x: number; y: number; panX: number; panY: number } | undefined>(undefined);
  const [imageUrl, setImageUrl] = useState<string>();
  const [imageSize, setImageSize] = useState<{ width: number; height: number }>();
  const [imageZoom, setImageZoom] = useState(1);
  const [imagePan, setImagePan] = useState({ x: 0, y: 0 });
  const [referenceDiameterMm, setReferenceDiameterMm] = useState(10);
  const [referenceDiameterPx, setReferenceDiameterPx] = useState(180);
  const [tool, setTool] = useState<MeasurementTool>('move');
  const [points, setPoints] = useState<MeasurementPoint[]>([]);

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
      setPoints([]);
    });
    reader.readAsDataURL(file);
  };

  const applyMeasurement = () => {
    const rect = viewportRef.current?.getBoundingClientRect();
    if (!measuredLengthMm || !imageUrl || !imageSize || !rect || rect.width <= 0 || rect.height <= 0) {
      return;
    }
    onApply({
      measuredLengthMm,
      referenceImage: createPatternReferenceImage({
        dataUrl: imageUrl,
        naturalWidth: imageSize.width,
        naturalHeight: imageSize.height,
        viewportWidth: rect.width,
        viewportHeight: rect.height,
        imageZoom,
        imagePan,
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
            <p>Facet {facetId} · model span {modelFacetLengthMm.toFixed(3)} mm</p>
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
              dragRef.current = {
                pointerId: event.pointerId,
                x: event.clientX,
                y: event.clientY,
                panX: imagePan.x,
                panY: imagePan.y,
              };
            }}
            onPointerMove={(event) => {
              const drag = dragRef.current;
              if (!drag || drag.pointerId !== event.pointerId) {
                return;
              }
              setImagePan({
                x: drag.panX + event.clientX - drag.x,
                y: drag.panY + event.clientY - drag.y,
              });
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
              <circle cx="50%" cy="50%" r={referenceDiameterPx / 2} className="measurementReferenceCircle" />
              {points.length === 2 ? (
                <line x1={points[0].x} y1={points[0].y} x2={points[1].x} y2={points[1].y} className="measurementLine" />
              ) : null}
              {points.map((point, index) => <circle key={index} cx={point.x} cy={point.y} r="5" className="measurementPoint" />)}
            </svg>
          </div>

          <aside className="measurementControls">
            <label className="fileButton toolbarButton measurementFileButton">
              Load photo
              <input type="file" accept="image/*" onChange={(event) => handleImage(event.target.files?.[0])} />
            </label>
            <div className="patternControls" role="group" aria-label="Measurement tool">
              <button className={tool === 'move' ? 'toolbarButton active' : 'toolbarButton'} onClick={() => setTool('move')}>Move photo</button>
              <button className={tool === 'measure' ? 'toolbarButton active' : 'toolbarButton'} disabled={!imageUrl} onClick={() => setTool('measure')}>Measure</button>
            </div>
            <RangeControl label="Photo scale" value={imageZoom} min={0.2} max={5} step={0.01} onChange={setImageZoom} />
            <NumberControl label="Reference diameter" value={referenceDiameterMm} min={0.001} step={0.1} suffix="mm" onChange={setReferenceDiameterMm} />
            <RangeControl label="Virtual circle" value={referenceDiameterPx} min={40} max={520} step={1} suffix="px" onChange={setReferenceDiameterPx} />
            <p className="measurementHint">Move and scale the photo until its reference circle matches the virtual circle. Then choose Measure and mark both ends of the real facet.</p>
            <dl className="measurementResult">
              <dt>Measured facet</dt>
              <dd>{measuredLengthMm ? `${measuredLengthMm.toFixed(3)} mm` : 'Select two points'}</dd>
              <dt>Model facet</dt>
              <dd>{modelFacetLengthMm.toFixed(3)} mm</dd>
              <dt>Scale factor</dt>
              <dd>{measuredLengthMm ? (measuredLengthMm / modelFacetLengthMm).toFixed(6) : '—'}</dd>
            </dl>
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

function NumberControl({ label, value, min, step, suffix, onChange }: {
  readonly label: string;
  readonly value: number;
  readonly min: number;
  readonly step: number;
  readonly suffix: string;
  readonly onChange: (value: number) => void;
}) {
  return (
    <label className="measurementControl measurementNumberControl">
      <span>{label}</span>
      <input type="number" value={value} min={min} step={step} onChange={(event) => onChange(Number(event.target.value))} />
      <output>{suffix}</output>
    </label>
  );
}
