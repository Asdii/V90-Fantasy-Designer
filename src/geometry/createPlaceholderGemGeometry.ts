import type { GemGeometry } from './GemGeometry';
import { createGemGeometryFromIndexedMesh } from './meshBuilder';

export function createPlaceholderGemGeometry(): GemGeometry {
  const vertices = [
    { x: -1, y: -1, z: -1 }, { x: 1, y: -1, z: -1 },
    { x: 1, y: 1, z: -1 }, { x: -1, y: 1, z: -1 },
    { x: -1, y: -1, z: 1 }, { x: 1, y: -1, z: 1 },
    { x: 1, y: 1, z: 1 }, { x: -1, y: 1, z: 1 },
  ];
  return createGemGeometryFromIndexedMesh(vertices, [
    { a: 0, b: 2, c: 1 }, { a: 0, b: 3, c: 2 },
    { a: 4, b: 5, c: 6 }, { a: 4, b: 6, c: 7 },
    { a: 0, b: 1, c: 5 }, { a: 0, b: 5, c: 4 },
    { a: 3, b: 7, c: 6 }, { a: 3, b: 6, c: 2 },
    { a: 0, b: 4, c: 7 }, { a: 0, b: 7, c: 3 },
    { a: 1, b: 2, c: 6 }, { a: 1, b: 6, c: 5 },
  ]);
}
