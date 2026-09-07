import type { GemGeometry } from './GemGeometry';

export function writeBinaryStl(geometry: GemGeometry, label = 'V90 Fantasy Designer'): ArrayBuffer {
  const buffer = new ArrayBuffer(84 + geometry.triangles.length * 50);
  const bytes = new Uint8Array(buffer);
  const view = new DataView(buffer);
  bytes.set(new TextEncoder().encode(label.slice(0, 80)), 0);
  view.setUint32(80, geometry.triangles.length, true);

  geometry.triangles.forEach((triangle, triangleIndex) => {
    let offset = 84 + triangleIndex * 50;
    for (const value of [triangle.normal.x, triangle.normal.y, triangle.normal.z]) {
      view.setFloat32(offset, value, true);
      offset += 4;
    }
    for (const vertexIndex of [triangle.a, triangle.b, triangle.c]) {
      const vertex = geometry.vertices[vertexIndex];
      for (const value of [vertex.x, vertex.y, vertex.z]) {
        view.setFloat32(offset, value, true);
        offset += 4;
      }
    }
    view.setUint16(offset, 0, true);
  });
  return buffer;
}
