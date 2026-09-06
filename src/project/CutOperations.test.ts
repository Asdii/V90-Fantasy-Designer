import { describe, expect, it } from 'vitest';
import { createPlaceholderGemGeometry } from '../geometry/createPlaceholderGemGeometry';
import type { CutOperation } from './GemProject';
import { rebuildWorkingGemGeometry } from './CutOperations';

describe('rebuildWorkingGemGeometry', () => {
  it('returns the untouched source when all cut operations are undone', async () => {
    const source = createPlaceholderGemGeometry();
    expect(await rebuildWorkingGemGeometry(source, [])).toBe(source);
  });

  it('replays a stored cut operation from domain geometry', async () => {
    const source = createPlaceholderGemGeometry();
    const operation: CutOperation = {
      id: 'cut-1',
      facetId: 0,
      patternSnapshot: { id: 'pattern', name: 'Test', primitives: [] },
      placement: { facetId: 0, offsetX: 0, offsetY: 0, rotationDeg: 0, scale: 1 },
      grooveSettings: { includedAngleDeg: 90, depthMm: 0.1 },
      facetNormal: { x: 0, y: 1, z: 0 },
      worldCutPaths: [{ points: [{ x: -0.2, y: 1, z: 0 }, { x: 0.2, y: 1, z: 0 }] }],
      cutPathCount: 1,
      cutHelper: {
        localGeometry: {
          frame: {
            origin: { x: 0, y: 1, z: 0 },
            uAxis: { x: 1, y: 0, z: 0 },
            vAxis: { x: 0, y: 0, z: 1 },
            normal: { x: 0, y: 1, z: 0 },
          },
          boundary: [],
          bounds: { minU: 0, maxU: 0, minV: 0, maxV: 0, width: 0, height: 0 },
        },
        instructions: [],
        grooveWidthMm: 0.2,
      },
    };
    const rebuilt = await rebuildWorkingGemGeometry(source, [operation]);
    expect(rebuilt).not.toBe(source);
    expect(rebuilt.triangles.length).toBeGreaterThan(source.triangles.length);
  });
});
