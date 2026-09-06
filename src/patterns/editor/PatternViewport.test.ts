import { describe, expect, it } from 'vitest';
import {
  createPatternViewportState,
  panPatternViewport,
  screenToWorld,
  worldToScreen,
  zoomPatternViewportAt,
} from './PatternViewport';

describe('PatternViewport transforms', () => {
  it('places world origin at viewport center initially', () => {
    const viewport = { ...createPatternViewportState(), width: 1000, height: 800, zoom: 1 };

    expect(worldToScreen({ x: 0, y: 0 }, viewport)).toEqual({ x: 500, y: 400 });
  });

  it('round-trips world and screen points', () => {
    const viewport = { width: 1200, height: 900, zoom: 37, panX: 125, panY: -80 };
    const points = [
      { x: 0, y: 0 },
      { x: 4.25, y: -8.5 },
      { x: -12, y: 2.75 },
    ];

    for (const point of points) {
      const roundTrip = screenToWorld(worldToScreen(point, viewport), viewport);
      expect(roundTrip.x).toBeCloseTo(point.x);
      expect(roundTrip.y).toBeCloseTo(point.y);
    }
  });

  it('applies pan in screen pixels', () => {
    const viewport = { ...createPatternViewportState(), width: 1000, height: 800, zoom: 1, panX: 100, panY: -50 };

    expect(worldToScreen({ x: 0, y: 0 }, viewport)).toEqual({ x: 600, y: 350 });
  });

  it('applies zoom around the viewport center', () => {
    const viewport = { ...createPatternViewportState(), width: 1000, height: 800, zoom: 2 };

    expect(worldToScreen({ x: 10, y: -5 }, viewport)).toEqual({ x: 520, y: 410 });
  });

  it('zooms toward cursor by keeping cursor world point stable', () => {
    const viewport = { ...createPatternViewportState(), width: 1000, height: 800, zoom: 10 };
    const cursor = { x: 750, y: 300 };
    const worldBefore = screenToWorld(cursor, viewport);
    const zoomed = zoomPatternViewportAt(viewport, cursor, 2);
    const worldAfter = screenToWorld(cursor, zoomed);

    expect(worldAfter.x).toBeCloseTo(worldBefore.x);
    expect(worldAfter.y).toBeCloseTo(worldBefore.y);
  });
});
