import type { GeometryWarning, Triangle, Vec3 } from './GemGeometry';
import { dot, triangleNormal } from './vectorMath';

export interface MeshOrientationResult {
  readonly triangles: readonly Triangle[];
  readonly signedVolume: number;
  readonly corrected: boolean;
  readonly warnings: readonly GeometryWarning[];
}

const VOLUME_EPSILON_MM3 = 1e-12;

export function orientTrianglesOutward(vertices: readonly Vec3[], triangles: readonly Triangle[]): MeshOrientationResult {
  const signedVolume = calculateSignedMeshVolume(vertices, triangles);
  const corrected = signedVolume < -VOLUME_EPSILON_MM3;
  const orientedTriangles = corrected ? flipTriangles(vertices, triangles) : triangles;
  const warnings: GeometryWarning[] = [];

  if (corrected) {
    warnings.push({
      code: 'inverted-winding-corrected',
      count: triangles.length,
      message: `Global STL winding was inverted; ${triangles.length} triangles were flipped to make normals outward`,
    });
  }

  return {
    triangles: orientedTriangles,
    signedVolume: corrected ? -signedVolume : signedVolume,
    corrected,
    warnings,
  };
}

export function calculateSignedMeshVolume(vertices: readonly Vec3[], triangles: readonly Pick<Triangle, 'a' | 'b' | 'c'>[]) {
  let volume = 0;
  for (const triangle of triangles) {
    const a = vertices[triangle.a];
    const b = vertices[triangle.b];
    const c = vertices[triangle.c];
    volume += dot(a, {
      x: b.y * c.z - b.z * c.y,
      y: b.z * c.x - b.x * c.z,
      z: b.x * c.y - b.y * c.x,
    });
  }
  return volume / 6;
}

function flipTriangles(vertices: readonly Vec3[], triangles: readonly Triangle[]): Triangle[] {
  return triangles.map((triangle) => ({
    a: triangle.a,
    b: triangle.c,
    c: triangle.b,
    normal: triangleNormal(vertices[triangle.a], vertices[triangle.c], vertices[triangle.b]),
  }));
}
