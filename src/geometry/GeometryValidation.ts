import type { GemGeometry, Vec3 } from './GemGeometry';

const DEGENERATE_AREA_EPSILON_SQUARED = 1e-24;

export interface GeometryValidationReport {
  readonly vertexCount: number;
  readonly triangleCount: number;
  readonly degenerateTriangleCount: number;
}

export function validateGemGeometry(geometry: GemGeometry): GeometryValidationReport {
  if (geometry.vertices.length === 0 || geometry.triangles.length === 0) {
    throw new Error('Geometry contains no renderable triangles.');
  }

  geometry.vertices.forEach((vertex, index) => assertFiniteVec3(vertex, `vertex ${index}`));

  let degenerateTriangleCount = 0;
  geometry.triangles.forEach((triangle, triangleIndex) => {
    for (const index of [triangle.a, triangle.b, triangle.c]) {
      if (!Number.isInteger(index) || index < 0 || index >= geometry.vertices.length) {
        throw new Error(`Triangle ${triangleIndex} contains invalid vertex index ${index}.`);
      }
    }
    assertFiniteVec3(triangle.normal, `triangle ${triangleIndex} normal`);
    if (triangle.a === triangle.b || triangle.b === triangle.c || triangle.a === triangle.c) {
      degenerateTriangleCount += 1;
      return;
    }

    const a = geometry.vertices[triangle.a];
    const b = geometry.vertices[triangle.b];
    const c = geometry.vertices[triangle.c];
    const ab = subtract(b, a);
    const ac = subtract(c, a);
    const cross = {
      x: ab.y * ac.z - ab.z * ac.y,
      y: ab.z * ac.x - ab.x * ac.z,
      z: ab.x * ac.y - ab.y * ac.x,
    };
    if (cross.x * cross.x + cross.y * cross.y + cross.z * cross.z <= DEGENERATE_AREA_EPSILON_SQUARED) {
      degenerateTriangleCount += 1;
    }
  });

  for (const [name, value] of Object.entries(geometry.boundingBox)) {
    assertFiniteVec3(value, `bounding box ${name}`);
  }
  if (geometry.boundingBox.size.x < 0 || geometry.boundingBox.size.y < 0 || geometry.boundingBox.size.z < 0) {
    throw new Error('Geometry bounding box has a negative size.');
  }

  const fatalTopology = geometry.warnings.filter(
    (warning) => warning.code === 'open-edges' || warning.code === 'non-manifold-edges',
  );
  if (fatalTopology.length > 0) {
    throw new Error(`Geometry is not a closed manifold: ${fatalTopology.map((warning) => warning.message).join('; ')}`);
  }

  return {
    vertexCount: geometry.vertices.length,
    triangleCount: geometry.triangles.length,
    degenerateTriangleCount,
  };
}

function assertFiniteVec3(value: Vec3, label: string) {
  if (![value.x, value.y, value.z].every(Number.isFinite)) {
    throw new Error(`Non-finite value found in ${label}.`);
  }
}

function subtract(a: Vec3, b: Vec3): Vec3 {
  return { x: a.x - b.x, y: a.y - b.y, z: a.z - b.z };
}
