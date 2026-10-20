import { describe, expect, it } from 'vitest';
import { createLinePrimitive } from '../model/PatternModel';
import { createRegularPolygonPrimitive } from '../editor/RegularPolygon';
import { radialDuplicatePrimitives } from './transforms';
import { inferPatternSymmetryConstraint, patternMatchesSymmetryConstraint } from './PatternSymmetryLock';

describe('PatternSymmetryLock', () => {
  it('infers sixfold dihedral symmetry from a triangle duplicated twice', () => {
    const triangle = createRegularPolygonPrimitive({ sides: 3, radius: 2, rotationDeg: -90 });
    const star = pattern(radialDuplicatePrimitives([triangle], 2, { x: 0, y: 0 }, 360));
    const constraint = inferPatternSymmetryConstraint(star);

    expect(constraint?.rotationOrder).toBe(6);
    expect(constraint?.reflectionAxisDeg).toBeDefined();
  });

  it('accepts an aligned hexagon added to the sixfold reference', () => {
    const triangle = createRegularPolygonPrimitive({ sides: 3, radius: 2, rotationDeg: -90 });
    const starPrimitives = radialDuplicatePrimitives([triangle], 2, { x: 0, y: 0 }, 360);
    const reference = pattern(starPrimitives);
    const constraint = inferPatternSymmetryConstraint(reference)!;
    const hexagon = createRegularPolygonPrimitive({ sides: 6, radius: 1.5, rotationDeg: -90 });

    expect(patternMatchesSymmetryConstraint(pattern([...starPrimitives, hexagon]), constraint)).toBe(true);
  });

  it('rejects an arbitrary single line added between sixfold elements', () => {
    const triangle = createRegularPolygonPrimitive({ sides: 3, radius: 2, rotationDeg: -90 });
    const starPrimitives = radialDuplicatePrimitives([triangle], 2, { x: 0, y: 0 }, 360);
    const reference = pattern(starPrimitives);
    const constraint = inferPatternSymmetryConstraint(reference)!;
    const line = createLinePrimitive({ x: 0.2, y: 0.1 }, { x: 1.3, y: 0.4 });

    expect(patternMatchesSymmetryConstraint(pattern([...starPrimitives, line]), constraint)).toBe(false);
  });

  it('rejects a sixfold shape whose mirror axes do not align with the first pattern', () => {
    const triangle = createRegularPolygonPrimitive({ sides: 3, radius: 2, rotationDeg: -90 });
    const starPrimitives = radialDuplicatePrimitives([triangle], 2, { x: 0, y: 0 }, 360);
    const reference = pattern(starPrimitives);
    const constraint = inferPatternSymmetryConstraint(reference)!;
    const misalignedHexagon = createRegularPolygonPrimitive({ sides: 6, radius: 1.5, rotationDeg: -80 });

    expect(patternMatchesSymmetryConstraint(pattern([...starPrimitives, misalignedHexagon]), constraint)).toBe(false);
  });

  it('accepts a sixfold orbit of aligned lines', () => {
    const triangle = createRegularPolygonPrimitive({ sides: 3, radius: 2, rotationDeg: -90 });
    const starPrimitives = radialDuplicatePrimitives([triangle], 2, { x: 0, y: 0 }, 360);
    const reference = pattern(starPrimitives);
    const constraint = inferPatternSymmetryConstraint(reference)!;
    const line = createLinePrimitive({ x: -0.75, y: -1.3 }, { x: 0.75, y: -1.3 });
    const lines = radialDuplicatePrimitives([line], 6, { x: 0, y: 0 }, 360);

    expect(patternMatchesSymmetryConstraint(pattern([...starPrimitives, ...lines]), constraint)).toBe(true);
  });
});

function pattern(primitives: ReturnType<typeof radialDuplicatePrimitives>) {
  return { id: 'test', name: 'test', primitives };
}
