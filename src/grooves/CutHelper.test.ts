import { describe, expect, it } from 'vitest';
import type { FacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import type { LineSegment2D } from '../patterns/Pattern';
import type { DesignPattern, PolylinePrimitive } from '../patterns/model/PatternModel';
import { createDefaultPatternPlacement } from '../patterns/placement/PatternPlacement';
import {
  calculateCutAngleDeg,
  calculateCutHelperStageRotation,
  calculateLineDistanceFromOriginMm,
  createCutInstructions,
  rebaseCutInstruction,
} from './CutHelper';

describe('CutHelper', () => {
  it('reports a centered upward lateral cut as 90 degrees at zero distance', () => {
    const segment = line(0, -10, 0, 10);

    expect(calculateCutAngleDeg(segment)).toBeCloseTo(90);
    expect(calculateLineDistanceFromOriginMm(segment)).toBeCloseTo(0);
  });

  it('reports a centered square as four ordered cuts at 15 mm', () => {
    const pattern = designPattern({
      id: 'square',
      type: 'polyline',
      role: 'pattern',
      points: [
        { x: -15, y: -15 },
        { x: 15, y: -15 },
        { x: 15, y: 15 },
        { x: -15, y: 15 },
      ],
      closed: true,
    });

    const instructions = createCutInstructions(
      pattern,
      createDefaultPatternPlacement(0),
      localGeometry(20),
      { includedAngleDeg: 90, depthMm: 0.05 },
    );

    expect(instructions.map((instruction) => instruction.angleDeg)).toEqual([0, 90, 180, 270]);
    expect(instructions.map((instruction) => instruction.distanceFromCenterMm)).toEqual([15, 15, 15, 15]);
    expect(instructions.every((instruction) => instruction.depthMm === 0.05)).toBe(true);
    expect(instructions.every((instruction) => instruction.visibleSegments.length === 1)).toBe(true);
  });

  it('rebases a later facet instruction onto the first facet center and axes', () => {
    const sourceBase = localGeometry(10);
    const source = {
      ...sourceBase,
      frame: { ...sourceBase.frame, origin: { x: 5, y: 2, z: 0 } },
    };
    const reference = localGeometry(10);
    const instruction = {
      id: 'cut',
      step: 1,
      angleDeg: 0,
      distanceFromCenterMm: 0,
      depthMm: 0.1,
      segment: line(-1, 0, 1, 0),
      visibleSegments: [line(-1, 0, 1, 0)],
    };

    const rebased = rebaseCutInstruction(instruction, source, reference);
    expect(rebased.segment.start).toEqual({ u: 4, v: 2 });
    expect(rebased.segment.end).toEqual({ u: 6, v: 2 });
    expect(rebased.angleDeg).toBeCloseTo(0);
    expect(rebased.distanceFromCenterMm).toBeCloseTo(2);
  });

  it('orients the cutting line horizontally or vertically', () => {
    expect(calculateCutHelperStageRotation(35, 'horizontal')).toBe(35);
    expect(calculateCutHelperStageRotation(35, 'vertical')).toBe(-55);
  });
});

function line(startU: number, startV: number, endU: number, endV: number): LineSegment2D {
  return { id: 'line', start: { u: startU, v: startV }, end: { u: endU, v: endV } };
}

function designPattern(primitive: PolylinePrimitive): DesignPattern {
  return { id: 'pattern', name: 'Cut helper test', primitives: [primitive] };
}

function localGeometry(radius: number): FacetLocalGeometry {
  return {
    frame: {
      origin: { x: 0, y: 0, z: 0 },
      uAxis: { x: 1, y: 0, z: 0 },
      vAxis: { x: 0, y: 1, z: 0 },
      normal: { x: 0, y: 0, z: 1 },
    },
    boundary: [
      { u: -radius, v: -radius },
      { u: radius, v: -radius },
      { u: radius, v: radius },
      { u: -radius, v: radius },
    ],
    bounds: {
      minU: -radius,
      maxU: radius,
      minV: -radius,
      maxV: radius,
      width: radius * 2,
      height: radius * 2,
    },
  };
}
