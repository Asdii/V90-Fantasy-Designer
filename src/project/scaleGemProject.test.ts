import { describe, expect, it } from 'vitest';
import { createFacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import { createPlaceholderGemGeometry } from '../geometry/createPlaceholderGemGeometry';
import type { GemProject } from './GemProject';
import { scaleGemProject } from './scaleGemProject';

describe('scaleGemProject', () => {
  it('scales source and working geometry without changing topology', () => {
    const geometry = createPlaceholderGemGeometry();
    const project: GemProject = {
      version: 1,
      sourceGeometry: geometry,
      geometry,
      cutOperations: [],
      patterns: {},
    };

    const scaled = scaleGemProject(project, 2);
    expect(scaled.geometry?.boundingBox.size.x).toBeCloseTo(geometry.boundingBox.size.x * 2);
    expect(scaled.sourceGeometry?.boundingBox.size.z).toBeCloseTo(geometry.boundingBox.size.z * 2);
    expect(scaled.geometry?.triangles).toHaveLength(geometry.triangles.length);
  });

  it('keeps existing cut history in the scaled millimeter system', () => {
    const geometry = createPlaceholderGemGeometry();
    const localGeometry = createFacetLocalGeometry(geometry, geometry.facets[0]);
    const project: GemProject = {
      version: 1,
      sourceGeometry: geometry,
      geometry,
      patterns: {},
      cutOperations: [{
        id: 'cut-1',
        facetId: 0,
        patternSnapshot: { id: 'pattern', name: 'Pattern', primitives: [] },
        placement: { facetId: 0, offsetX: 1, offsetY: -2, rotationDeg: 30, scale: 0.5 },
        grooveSettings: { includedAngleDeg: 90, depthMm: 0.05 },
        facetNormal: localGeometry.frame.normal,
        worldCutPaths: [{ points: [{ x: 1, y: 0, z: 0 }, { x: 2, y: 0, z: 0 }] }],
        cutPathCount: 1,
        cutHelper: {
          localGeometry,
          grooveWidthMm: 0.1,
          instructions: [{
            id: 'line',
            step: 1,
            angleDeg: 0,
            distanceFromCenterMm: 1,
            depthMm: 0.05,
            segment: { id: 'line', start: { u: 0, v: 1 }, end: { u: 2, v: 1 } },
            visibleSegments: [],
          }],
        },
      }],
    };

    const scaled = scaleGemProject(project, 2);
    const operation = scaled.cutOperations[0];
    expect(operation.placement.offsetX).toBeCloseTo(2);
    expect(operation.placement.offsetY).toBeCloseTo(-4);
    expect(operation.placement.scale).toBeCloseTo(1);
    expect(operation.grooveSettings.depthMm).toBeCloseTo(0.1);
    expect(operation.cutHelper.grooveWidthMm).toBeCloseTo(0.2);
    expect(operation.cutHelper.instructions[0].distanceFromCenterMm).toBeCloseTo(2);
    expect(operation.cutHelper.instructions[0].segment.end.u).toBeCloseTo(4);
  });
});
