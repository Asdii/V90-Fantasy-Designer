import { describe, expect, it } from 'vitest';
import { areCutPlaneNormalsCompatible } from './CutPlaneLock';

describe('areCutPlaneNormalsCompatible', () => {
  it('accepts facets with the same cutting angle', () => {
    const angle = (0.05 * Math.PI) / 180;
    expect(areCutPlaneNormalsCompatible(
      { x: 0, y: 0, z: 1 },
      { x: Math.sin(angle), y: 0, z: Math.cos(angle) },
    )).toBe(true);
  });

  it('rejects a facet at a different angle and an opposite-facing facet', () => {
    const angle = (30 * Math.PI) / 180;
    expect(areCutPlaneNormalsCompatible(
      { x: 0, y: 0, z: 1 },
      { x: Math.sin(angle), y: 0, z: Math.cos(angle) },
    )).toBe(false);
    expect(areCutPlaneNormalsCompatible(
      { x: 0, y: 0, z: 1 },
      { x: 0, y: 0, z: -1 },
    )).toBe(false);
  });
});
