import type { PatternBounds } from '../geometry/bounds';
import type { Vec2 } from '../model/PatternModel';

export interface PatternViewportState {
  readonly zoom: number;
  readonly panX: number;
  readonly panY: number;
  readonly width: number;
  readonly height: number;
}

export const DEFAULT_PATTERN_ZOOM = 48;

export function createPatternViewportState(width = 1, height = 1): PatternViewportState {
  return {
    zoom: DEFAULT_PATTERN_ZOOM,
    panX: 0,
    panY: 0,
    width,
    height,
  };
}

export function worldToScreen(point: Vec2, viewport: PatternViewportState): Vec2 {
  return {
    x: viewport.width / 2 + viewport.panX + point.x * viewport.zoom,
    y: viewport.height / 2 + viewport.panY - point.y * viewport.zoom,
  };
}

export function screenToWorld(point: Vec2, viewport: PatternViewportState): Vec2 {
  return {
    x: (point.x - viewport.width / 2 - viewport.panX) / viewport.zoom,
    y: -(point.y - viewport.height / 2 - viewport.panY) / viewport.zoom,
  };
}

export function resizePatternViewport(
  viewport: PatternViewportState,
  width: number,
  height: number,
): PatternViewportState {
  return {
    ...viewport,
    width: Math.max(1, width),
    height: Math.max(1, height),
  };
}

export function panPatternViewport(
  viewport: PatternViewportState,
  deltaX: number,
  deltaY: number,
): PatternViewportState {
  return {
    ...viewport,
    panX: viewport.panX + deltaX,
    panY: viewport.panY + deltaY,
  };
}

export function zoomPatternViewportAt(
  viewport: PatternViewportState,
  screenPoint: Vec2,
  zoomFactor: number,
  minZoom = 8,
  maxZoom = 240,
): PatternViewportState {
  const worldBefore = screenToWorld(screenPoint, viewport);
  const zoom = Math.max(minZoom, Math.min(maxZoom, viewport.zoom * zoomFactor));
  return {
    ...viewport,
    zoom,
    panX: screenPoint.x - viewport.width / 2 - worldBefore.x * zoom,
    panY: screenPoint.y - viewport.height / 2 + worldBefore.y * zoom,
  };
}

export function resetPatternViewport(viewport: PatternViewportState): PatternViewportState {
  return {
    ...viewport,
    zoom: DEFAULT_PATTERN_ZOOM,
    panX: 0,
    panY: 0,
  };
}

export function fitBoundsInViewport(
  viewport: PatternViewportState,
  bounds: PatternBounds,
  marginRatio = 0.12,
): PatternViewportState {
  if (bounds.width <= 0 && bounds.height <= 0) {
    return resetPatternViewport(viewport);
  }

  const usableWidth = viewport.width * (1 - marginRatio * 2);
  const usableHeight = viewport.height * (1 - marginRatio * 2);
  const zoom = Math.max(
    8,
    Math.min(
      240,
      Math.min(
        bounds.width > 0 ? usableWidth / bounds.width : Number.POSITIVE_INFINITY,
        bounds.height > 0 ? usableHeight / bounds.height : Number.POSITIVE_INFINITY,
      ),
    ),
  );

  return {
    ...viewport,
    zoom,
    panX: -bounds.center.x * zoom,
    panY: bounds.center.y * zoom,
  };
}

export function getVisibleWorldBounds(viewport: PatternViewportState) {
  const topLeft = screenToWorld({ x: 0, y: 0 }, viewport);
  const bottomRight = screenToWorld({ x: viewport.width, y: viewport.height }, viewport);
  return {
    minX: Math.min(topLeft.x, bottomRight.x),
    maxX: Math.max(topLeft.x, bottomRight.x),
    minY: Math.min(topLeft.y, bottomRight.y),
    maxY: Math.max(topLeft.y, bottomRight.y),
  };
}
