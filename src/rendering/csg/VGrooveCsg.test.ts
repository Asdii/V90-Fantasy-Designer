import { describe, expect, it } from 'vitest';
import type { FacetFrame } from '../../geometry/FacetFrame';
import { createFacetLocalGeometry } from '../../geometry/FacetLocalGeometry';
import { createPlaceholderGemGeometry } from '../../geometry/createPlaceholderGemGeometry';
import { createGemGeometryFromTriangleSoup } from '../../geometry/meshBuilder';
import { createLinePrimitive, type DesignPattern } from '../../patterns/model/PatternModel';
import { patternPlacementToWorldCutPaths } from '../../patterns/placement/PatternPlacement';
import { subtractVGroovesFromGemGeometry } from './VGrooveCsg';

describe('VGrooveCsg', () => {
  it('creates a modified GemGeometry with additional V-wall surfaces', async () => {
    const gem = createBoxGem();
    const stages: string[] = [];
    const result = await subtractVGroovesFromGemGeometry(
      gem,
      [{ points: [{ x: -0.6, y: 0, z: 0.5 }, { x: 0.6, y: 0, z: 0.5 }] }],
      topFrame,
      { includedAngleDeg: 90, depthMm: 0.2 },
      (stage) => stages.push(stage),
    );

    expect(result.trianglesBefore).toBe(gem.triangles.length);
    expect(result.trianglesAfter).toBeGreaterThan(result.trianglesBefore);
    expect(result.geometry.triangles.length).toBe(result.trianglesAfter);
    expect(result.geometry.facets.length).toBeGreaterThan(gem.facets.length);
    expect(stages).toEqual([
      'csg-started',
      'cutter-geometry-ready',
      'csg-completed',
      'domain-conversion-started',
      'domain-conversion-completed',
      'geometry-validated',
    ]);
  });

  it('subtracts five independent cutters without producing an invalid mesh', async () => {
    const gem = createBoxGem();
    const paths = [-0.4, -0.2, 0, 0.2, 0.4].map((y) => ({
      points: [{ x: -0.6, y, z: 0.5 }, { x: 0.6, y, z: 0.5 }],
    }));
    const result = await subtractVGroovesFromGemGeometry(
      gem,
      paths,
      topFrame,
      { includedAngleDeg: 90, depthMm: 0.06 },
    );
    expect(result.cutPathCount).toBe(5);
    expect(result.geometry.warnings.some((warning) => warning.code === 'open-edges' || warning.code === 'non-manifold-edges')).toBe(false);
  });

  it('subtracts intersecting cutters without leaving invalid internal faces', async () => {
    const gem = createBoxGem();
    const result = await subtractVGroovesFromGemGeometry(
      gem,
      [
        { points: [{ x: -0.8, y: 0, z: 0.5 }, { x: 0.8, y: 0, z: 0.5 }] },
        { points: [{ x: 0, y: -0.8, z: 0.5 }, { x: 0, y: 0.8, z: 0.5 }] },
      ],
      topFrame,
      { includedAngleDeg: 90, depthMm: 0.2 },
    );

    expect(result.cutPathCount).toBe(2);
    expect(result.geometry.warnings.some((warning) => warning.code === 'open-edges' || warning.code === 'non-manifold-edges')).toBe(false);
  });

  it('supports a scaled radial pattern clipped at the facet boundary', async () => {
    const gem = createBoxGem();
    const paths = [
      [{ x: -1, y: 0, z: 0.5 }, { x: 1, y: 0, z: 0.5 }],
      [{ x: 0, y: -1, z: 0.5 }, { x: 0, y: 1, z: 0.5 }],
      [{ x: -1, y: -1, z: 0.5 }, { x: 1, y: 1, z: 0.5 }],
      [{ x: -1, y: 1, z: 0.5 }, { x: 1, y: -1, z: 0.5 }],
    ].map((points) => ({ points }));

    const result = await subtractVGroovesFromGemGeometry(
      gem,
      paths,
      topFrame,
      { includedAngleDeg: 90, depthMm: 0.12 },
    );

    expect(result.cutPathCount).toBe(4);
    expect(result.geometry.warnings.some((warning) => warning.code === 'open-edges' || warning.code === 'non-manifold-edges')).toBe(false);
  });

  it('cuts four extended square lines through an inclined placeholder facet', async () => {
    const gem = createPlaceholderGemGeometry();
    const facet = gem.facets.find((candidate) => candidate.id === 0)!;
    const localGeometry = createFacetLocalGeometry(gem, facet);
    const square: DesignPattern = {
      id: 'four-line-square',
      name: 'Four line square',
      primitives: [
        createLinePrimitive({ x: -3, y: -3 }, { x: 3, y: -3 }),
        createLinePrimitive({ x: 3, y: -3 }, { x: 3, y: 3 }),
        createLinePrimitive({ x: 3, y: 3 }, { x: -3, y: 3 }),
        createLinePrimitive({ x: -3, y: 3 }, { x: -3, y: -3 }),
      ],
    };
    const paths = patternPlacementToWorldCutPaths(
      square,
      { facetId: facet.id, offsetX: 0, offsetY: 0, rotationDeg: 0, scale: 0.161 },
      localGeometry,
    );

    expect(paths).toHaveLength(4);
    const result = await subtractVGroovesFromGemGeometry(
      gem,
      paths,
      localGeometry.frame,
      { includedAngleDeg: 90, depthMm: 0.09 },
    );

    expect(result.cutPathCount).toBe(4);
    expect(result.geometry.warnings.some((warning) => warning.code === 'open-edges' || warning.code === 'non-manifold-edges')).toBe(false);
  });

  it('cuts a dense 16-line rotated-square pattern at shallow depth', async () => {
    const gem = createBoxGem(5, 1);
    const paths = Array.from({ length: 4 }, (_, rotationIndex) => {
      const angle = (rotationIndex * 22.5 * Math.PI) / 180;
      const corners = [
        { x: -2, y: -2 },
        { x: 2, y: -2 },
        { x: 2, y: 2 },
        { x: -2, y: 2 },
      ].map((point) => ({
        x: point.x * Math.cos(angle) - point.y * Math.sin(angle),
        y: point.x * Math.sin(angle) + point.y * Math.cos(angle),
      }));
      return corners.map((start, index) => {
        const end = corners[(index + 1) % corners.length];
        const dx = end.x - start.x;
        const dy = end.y - start.y;
        const length = Math.hypot(dx, dy);
        const center = { x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 };
        return {
          points: [
            { x: center.x - (dx / length) * 20, y: center.y - (dy / length) * 20, z: 1 },
            { x: center.x + (dx / length) * 20, y: center.y + (dy / length) * 20, z: 1 },
          ],
        };
      });
    }).flat();

    const result = await subtractVGroovesFromGemGeometry(
      gem,
      paths,
      topFrame,
      { includedAngleDeg: 90, depthMm: 0.01 },
    );

    expect(result.cutPathCount).toBe(16);
    expect(result.geometry.warnings.some((warning) => warning.code === 'open-edges' || warning.code === 'non-manifold-edges')).toBe(false);
  });
});

const topFrame: Pick<FacetFrame, 'normal'> = {
  normal: { x: 0, y: 0, z: 1 },
};

function createBoxGem(halfSize = 1, zMax = 0.5) {
  const min = -halfSize;
  const max = halfSize;
  const zMin = -zMax;
  return createGemGeometryFromTriangleSoup([
    [{ x: min, y: min, z: zMax }, { x: max, y: min, z: zMax }, { x: max, y: max, z: zMax }],
    [{ x: min, y: min, z: zMax }, { x: max, y: max, z: zMax }, { x: min, y: max, z: zMax }],
    [{ x: min, y: min, z: zMin }, { x: max, y: max, z: zMin }, { x: max, y: min, z: zMin }],
    [{ x: min, y: min, z: zMin }, { x: min, y: max, z: zMin }, { x: max, y: max, z: zMin }],
    [{ x: min, y: max, z: zMin }, { x: min, y: max, z: zMax }, { x: max, y: max, z: zMax }],
    [{ x: min, y: max, z: zMin }, { x: max, y: max, z: zMax }, { x: max, y: max, z: zMin }],
    [{ x: min, y: min, z: zMin }, { x: max, y: min, z: zMax }, { x: min, y: min, z: zMax }],
    [{ x: min, y: min, z: zMin }, { x: max, y: min, z: zMin }, { x: max, y: min, z: zMax }],
    [{ x: max, y: min, z: zMin }, { x: max, y: max, z: zMax }, { x: max, y: min, z: zMax }],
    [{ x: max, y: min, z: zMin }, { x: max, y: max, z: zMin }, { x: max, y: max, z: zMax }],
    [{ x: min, y: min, z: zMin }, { x: min, y: min, z: zMax }, { x: min, y: max, z: zMax }],
    [{ x: min, y: min, z: zMin }, { x: min, y: max, z: zMax }, { x: min, y: max, z: zMin }],
  ]);
}
