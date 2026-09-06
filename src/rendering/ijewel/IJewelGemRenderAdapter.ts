import { BufferGeometry, Float32BufferAttribute, Mesh, type Material } from 'webgi';
import type { GemGeometry } from '../../geometry/GemGeometry';

/** Converts the renderer-independent, double-precision model to a faceted iJewel GPU buffer. */
export function createIJewelGeometry(geometry: GemGeometry): BufferGeometry {
  const positions = new Float32Array(geometry.triangles.length * 9);
  const normals = new Float32Array(geometry.triangles.length * 9);

  geometry.triangles.forEach((triangle, triangleIndex) => {
    const vertices = [
      geometry.vertices[triangle.a],
      geometry.vertices[triangle.b],
      geometry.vertices[triangle.c],
    ];
    const offset = triangleIndex * 9;
    for (let corner = 0; corner < 3; corner += 1) {
      const vertex = vertices[corner];
      const target = offset + corner * 3;
      positions[target] = vertex.x;
      positions[target + 1] = vertex.y;
      positions[target + 2] = vertex.z;
      normals[target] = triangle.normal.x;
      normals[target + 1] = triangle.normal.y;
      normals[target + 2] = triangle.normal.z;
    }
  });

  const result = new BufferGeometry();
  result.setAttribute('position', new Float32BufferAttribute(positions, 3));
  result.setAttribute('normal', new Float32BufferAttribute(normals, 3));
  result.computeBoundingBox();
  result.computeBoundingSphere();
  return result;
}

export function createIJewelMesh(geometry: BufferGeometry, material: Material) {
  return new Mesh(geometry, material);
}
