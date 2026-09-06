import type { Vec3 } from './GemGeometry';
import { createGemGeometryFromTriangleSoup, type MeshBuildOptions, type TriangleSoup } from './meshBuilder';

export function parseStl(buffer: ArrayBuffer, options?: MeshBuildOptions) {
  const soup = isBinaryStl(buffer) ? parseBinaryStl(buffer) : parseAsciiStl(buffer);
  return createGemGeometryFromTriangleSoup(soup, options);
}

function isBinaryStl(buffer: ArrayBuffer) {
  if (buffer.byteLength < 84) {
    return false;
  }

  const view = new DataView(buffer);
  const triangleCount = view.getUint32(80, true);
  const expectedBinaryLength = 84 + triangleCount * 50;

  if (expectedBinaryLength === buffer.byteLength) {
    return true;
  }

  const header = new TextDecoder().decode(buffer.slice(0, Math.min(buffer.byteLength, 256))).trimStart();
  return !header.toLowerCase().startsWith('solid');
}

function parseBinaryStl(buffer: ArrayBuffer): TriangleSoup {
  const view = new DataView(buffer);
  const triangleCount = view.getUint32(80, true);
  const triangles: [Vec3, Vec3, Vec3][] = [];
  let offset = 84;

  for (let index = 0; index < triangleCount; index += 1) {
    offset += 12;
    const a = readBinaryVec3(view, offset);
    offset += 12;
    const b = readBinaryVec3(view, offset);
    offset += 12;
    const c = readBinaryVec3(view, offset);
    offset += 12;
    offset += 2;
    triangles.push([a, b, c]);
  }

  return triangles;
}

function readBinaryVec3(view: DataView, offset: number): Vec3 {
  return {
    x: view.getFloat32(offset, true),
    y: view.getFloat32(offset + 4, true),
    z: view.getFloat32(offset + 8, true),
  };
}

function parseAsciiStl(buffer: ArrayBuffer): TriangleSoup {
  const text = new TextDecoder().decode(buffer);
  const vertices: Vec3[] = [];
  const vertexPattern = /vertex\s+([+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?)\s+([+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?)\s+([+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?)/gi;
  let match: RegExpExecArray | null;

  while ((match = vertexPattern.exec(text)) !== null) {
    vertices.push({
      x: Number(match[1]),
      y: Number(match[2]),
      z: Number(match[3]),
    });
  }

  const triangles: [Vec3, Vec3, Vec3][] = [];
  for (let index = 0; index + 2 < vertices.length; index += 3) {
    triangles.push([vertices[index], vertices[index + 1], vertices[index + 2]]);
  }

  return triangles;
}
