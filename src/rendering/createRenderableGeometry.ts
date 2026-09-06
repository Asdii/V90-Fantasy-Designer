import * as THREE from 'three';
import type { Facet } from '../geometry/Facet';
import type { GemGeometry } from '../geometry/GemGeometry';

interface RenderableGeometryOptions {
  readonly facetColors?: boolean;
}

export function createRenderableGeometry(
  geometry: GemGeometry,
  options: RenderableGeometryOptions = {},
): THREE.BufferGeometry {
  const positions = new Float32Array(geometry.triangles.length * 9);
  const normals = new Float32Array(geometry.triangles.length * 9);
  const colors = options.facetColors ? new Float32Array(geometry.triangles.length * 9) : undefined;
  const triangleFacetIds = buildTriangleFacetIdMap(geometry);

  geometry.triangles.forEach((triangle, triangleIndex) => {
    const offset = triangleIndex * 9;
    const vertices = [geometry.vertices[triangle.a], geometry.vertices[triangle.b], geometry.vertices[triangle.c]];
    const color = colors ? debugColorForFacet(triangleFacetIds[triangleIndex] ?? 0) : undefined;

    vertices.forEach((vertex, vertexOffset) => {
      const positionOffset = offset + vertexOffset * 3;
      positions[positionOffset] = vertex.x;
      positions[positionOffset + 1] = vertex.y;
      positions[positionOffset + 2] = vertex.z;
      normals[positionOffset] = triangle.normal.x;
      normals[positionOffset + 1] = triangle.normal.y;
      normals[positionOffset + 2] = triangle.normal.z;

      if (colors && color) {
        colors[positionOffset] = color.r;
        colors[positionOffset + 1] = color.g;
        colors[positionOffset + 2] = color.b;
      }
    });
  });

  const bufferGeometry = new THREE.BufferGeometry();
  bufferGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  bufferGeometry.setAttribute('normal', new THREE.BufferAttribute(normals, 3));
  if (colors) {
    bufferGeometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  }
  return bufferGeometry;
}

export function createFacetBoundaryGeometry(geometry: GemGeometry): THREE.BufferGeometry {
  const positions: number[] = [];

  for (const facet of geometry.facets) {
    for (const edge of facet.boundaryEdges) {
      const a = geometry.vertices[edge.a];
      const b = geometry.vertices[edge.b];
      positions.push(a.x, a.y, a.z, b.x, b.y, b.z);
    }
  }

  const bufferGeometry = new THREE.BufferGeometry();
  bufferGeometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(positions), 3));
  return bufferGeometry;
}

export function createFacetSurfaceGeometry(geometry: GemGeometry, facet: Facet): THREE.BufferGeometry {
  const positions = new Float32Array(facet.triangleIndices.length * 9);
  const normals = new Float32Array(facet.triangleIndices.length * 9);

  facet.triangleIndices.forEach((triangleIndex, facetTriangleIndex) => {
    const triangle = geometry.triangles[triangleIndex];
    const offset = facetTriangleIndex * 9;
    const vertices = [geometry.vertices[triangle.a], geometry.vertices[triangle.b], geometry.vertices[triangle.c]];

    vertices.forEach((vertex, vertexOffset) => {
      const positionOffset = offset + vertexOffset * 3;
      positions[positionOffset] = vertex.x;
      positions[positionOffset + 1] = vertex.y;
      positions[positionOffset + 2] = vertex.z;
      normals[positionOffset] = facet.normal.x;
      normals[positionOffset + 1] = facet.normal.y;
      normals[positionOffset + 2] = facet.normal.z;
    });
  });

  const bufferGeometry = new THREE.BufferGeometry();
  bufferGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  bufferGeometry.setAttribute('normal', new THREE.BufferAttribute(normals, 3));
  return bufferGeometry;
}

export function createSingleFacetBoundaryGeometry(geometry: GemGeometry, facet: Facet): THREE.BufferGeometry {
  const positions: number[] = [];

  for (const edge of facet.boundaryEdges) {
    const a = geometry.vertices[edge.a];
    const b = geometry.vertices[edge.b];
    positions.push(a.x, a.y, a.z, b.x, b.y, b.z);
  }

  const bufferGeometry = new THREE.BufferGeometry();
  bufferGeometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(positions), 3));
  return bufferGeometry;
}

function buildTriangleFacetIdMap(geometry: GemGeometry): number[] {
  const map = new Array<number>(geometry.triangles.length);

  for (const facet of geometry.facets) {
    for (const triangleIndex of facet.triangleIndices) {
      map[triangleIndex] = facet.id;
    }
  }

  return map;
}

function debugColorForFacet(facetId: number): THREE.Color {
  const hue = (facetId * 0.618033988749895) % 1;
  return new THREE.Color().setHSL(hue, 0.68, 0.58);
}
