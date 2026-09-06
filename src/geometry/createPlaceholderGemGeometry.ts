import type { GemGeometry } from './GemGeometry';
import { createGemGeometryFromTriangleSoup } from './meshBuilder';

export function createPlaceholderGemGeometry(): GemGeometry {
  return createGemGeometryFromTriangleSoup(
    [
      [{ x: 0, y: 1.2, z: 0 }, { x: 1.2, y: 0, z: 0 }, { x: 0, y: 0, z: 1.2 }],
      [{ x: 0, y: 1.2, z: 0 }, { x: 0, y: 0, z: 1.2 }, { x: -1.2, y: 0, z: 0 }],
      [{ x: 0, y: 1.2, z: 0 }, { x: -1.2, y: 0, z: 0 }, { x: 0, y: 0, z: -1.2 }],
      [{ x: 0, y: 1.2, z: 0 }, { x: 0, y: 0, z: -1.2 }, { x: 1.2, y: 0, z: 0 }],
      [{ x: 0, y: -1.2, z: 0 }, { x: 0, y: 0, z: 1.2 }, { x: 1.2, y: 0, z: 0 }],
      [{ x: 0, y: -1.2, z: 0 }, { x: -1.2, y: 0, z: 0 }, { x: 0, y: 0, z: 1.2 }],
      [{ x: 0, y: -1.2, z: 0 }, { x: 0, y: 0, z: -1.2 }, { x: -1.2, y: 0, z: 0 }],
      [{ x: 0, y: -1.2, z: 0 }, { x: 1.2, y: 0, z: 0 }, { x: 0, y: 0, z: -1.2 }],
    ],
  );
}
