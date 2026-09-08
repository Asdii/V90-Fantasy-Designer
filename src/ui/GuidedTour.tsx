import { useEffect, useLayoutEffect, useState } from 'react';
import type { CSSProperties } from 'react';

export interface GuidedTourStep {
  readonly title: string;
  readonly description: string;
  readonly target: string;
}

interface GuidedTourProps {
  readonly steps: readonly GuidedTourStep[];
  readonly onClose: () => void;
}

interface HighlightRect {
  readonly left: number;
  readonly top: number;
  readonly width: number;
  readonly height: number;
}

export function GuidedTour({ steps, onClose }: GuidedTourProps) {
  const [index, setIndex] = useState(0);
  const [rect, setRect] = useState<HighlightRect>();
  const step = steps[index];

  useLayoutEffect(() => {
    const update = () => {
      const target = document.querySelector<HTMLElement>(step.target);
      if (!target) {
        setRect(undefined);
        return;
      }
      const bounds = target.getBoundingClientRect();
      const padding = 7;
      setRect({
        left: Math.max(6, bounds.left - padding),
        top: Math.max(6, bounds.top - padding),
        width: Math.min(window.innerWidth - 12, bounds.width + padding * 2),
        height: Math.min(window.innerHeight - 12, bounds.height + padding * 2),
      });
    };
    update();
    window.addEventListener('resize', update);
    window.addEventListener('scroll', update, true);
    const observer = new ResizeObserver(update);
    observer.observe(document.body);
    return () => {
      observer.disconnect();
      window.removeEventListener('resize', update);
      window.removeEventListener('scroll', update, true);
    };
  }, [step.target]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
      if (event.key === 'ArrowRight') setIndex((current) => Math.min(steps.length - 1, current + 1));
      if (event.key === 'ArrowLeft') setIndex((current) => Math.max(0, current - 1));
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose, steps.length]);

  const cardStyle = calculateCardPosition(rect);
  return (
    <div className="guidedTour" role="dialog" aria-modal="true" aria-label="Guided application tour">
      {rect ? <div className="guidedTourSpotlight" style={rect} /> : <div className="guidedTourShade" />}
      <section className="guidedTourCard" style={cardStyle}>
        <span className="guidedTourProgress">Step {index + 1} of {steps.length}</span>
        <h2>{step.title}</h2>
        <p>{step.description}</p>
        <div className="guidedTourActions">
          <button className="toolbarButton" onClick={onClose}>Skip</button>
          <span />
          <button className="toolbarButton" disabled={index === 0} onClick={() => setIndex((current) => current - 1)}>Previous</button>
          {index === steps.length - 1 ? (
            <button className="toolbarButton active" onClick={onClose}>Finish</button>
          ) : (
            <button className="toolbarButton active" onClick={() => setIndex((current) => current + 1)}>Next</button>
          )}
        </div>
      </section>
    </div>
  );
}

function calculateCardPosition(rect?: HighlightRect): CSSProperties {
  const width = Math.min(360, window.innerWidth - 24);
  if (!rect) {
    return { width, left: (window.innerWidth - width) / 2, top: Math.max(12, window.innerHeight / 2 - 120) };
  }
  const left = Math.max(12, Math.min(window.innerWidth - width - 12, rect.left + rect.width / 2 - width / 2));
  const below = rect.top + rect.height + 14;
  const top = below + 230 < window.innerHeight ? below : Math.max(12, rect.top - 244);
  return { width, left, top };
}
