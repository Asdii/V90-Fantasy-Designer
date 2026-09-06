import { describe, expect, it } from 'vitest';
import {
  createArcPrimitive,
  createCirclePrimitive,
  createLinePrimitive,
  createPolylinePrimitive,
  type DesignPattern,
} from '../model/PatternModel';
import { normalizePattern, patternToCutPaths } from './pathConversion';

describe('patternToCutPaths', () => {
  it('excludes construction geometry from cut paths', () => {
    const pattern: DesignPattern = {
      id: 'p',
      name: 'p',
      primitives: [
        createLinePrimitive({ x: 0, y: 0 }, { x: 1, y: 0 }, 'pattern'),
        createLinePrimitive({ x: 0, y: 0 }, { x: 0, y: 1 }, 'construction'),
      ],
    };

    const paths = patternToCutPaths(pattern);

    expect(paths).toHaveLength(1);
    expect(paths[0].points).toEqual([{ x: 0, y: 0 }, { x: 1, y: 0 }]);
  });

  it('converts primitives to mathematical paths', () => {
    const pattern: DesignPattern = {
      id: 'p',
      name: 'p',
      primitives: [
        createPolylinePrimitive(
          [
            { x: 0, y: 0 },
            { x: 1, y: 0 },
            { x: 1, y: 1 },
          ],
          true,
        ),
        createCirclePrimitive({ x: 0, y: 0 }, 1),
        createArcPrimitive({ x: 0, y: 0 }, 1, 0, 90),
      ],
    };

    const paths = patternToCutPaths(pattern, 8);

    expect(paths).toHaveLength(3);
    expect(paths[0].closed).toBe(true);
    expect(paths[1].closed).toBe(true);
    expect(paths[1].points).toHaveLength(9);
    expect(paths[2].closed).toBe(false);
    expect(paths[2].points.at(0)?.x).toBeCloseTo(1);
    expect(paths[2].points.at(-1)?.y).toBeCloseTo(1);
  });

  it('normalizes a pattern without modifying the original geometry', () => {
    const line = createLinePrimitive({ x: -5, y: 0 }, { x: 5, y: 0 });
    const pattern: DesignPattern = { id: 'p', name: 'p', primitives: [line] };

    const normalized = normalizePattern(pattern);

    expect(normalized.primitives[0]).toMatchObject({ start: { x: -1, y: 0 }, end: { x: 1, y: 0 } });
    expect(pattern.primitives[0]).toBe(line);
  });

  it('keeps the fixed pattern origin when normalizing off-center geometry', () => {
    const pattern: DesignPattern = {
      id: 'p',
      name: 'p',
      primitives: [createLinePrimitive({ x: 10, y: 0 }, { x: 20, y: 0 })],
    };

    const normalized = normalizePattern(pattern);

    expect(normalized.primitives[0]).toMatchObject({ start: { x: 2, y: 0 }, end: { x: 4, y: 0 } });
  });
});
