import Module, { type Manifold as ManifoldSolid, type ManifoldToplevel } from 'manifold-3d';
import type { FacetFrame } from '../../geometry/FacetFrame';
import type { GemGeometry, Vec3 } from '../../geometry/GemGeometry';
import { validateGemGeometry } from '../../geometry/GeometryValidation';
import { createGemGeometryFromIndexedMesh, type IndexedTriangle } from '../../geometry/meshBuilder';
import { generateVGrooveCutterGeometry, type VGrooveSettings } from '../../grooves';
import type { GroovePreviewGeometry } from '../../grooves/GroovePreviewGeometry';
import type { WorldCutPath } from '../../patterns/placement/PatternPlacement';

export type CreateCutsStage =
  | 'cutter-geometry-ready'
  | 'csg-started'
  | 'csg-completed'
  | 'domain-conversion-started'
  | 'domain-conversion-completed'
  | 'geometry-validated';

export interface CreateCutsResult {
  readonly geometry: GemGeometry;
  readonly cutPathCount: number;
  readonly trianglesBefore: number;
  readonly trianglesAfter: number;
}

let manifoldModulePromise: Promise<ManifoldToplevel> | undefined;

export async function subtractVGroovesFromGemGeometry(
  geometry: GemGeometry,
  cutPaths: readonly WorldCutPath[],
  frame: Pick<FacetFrame, 'normal'>,
  settings: VGrooveSettings,
  onStage?: (stage: CreateCutsStage) => void,
): Promise<CreateCutsResult> {
  validateGemGeometry(geometry);
  const validCutPaths = cutPaths.filter((path) => path.points.length >= 2);
  if (validCutPaths.length === 0) {
    return {
      geometry,
      cutPathCount: 0,
      trianglesBefore: geometry.triangles.length,
      trianglesAfter: geometry.triangles.length,
    };
  }

  const wasm = await getManifoldModule();
  let gem: ManifoldSolid | undefined;
  let cutterUnion: ManifoldSolid | undefined;
  let result: ManifoldSolid | undefined;
  const cutters: ManifoldSolid[] = [];

  try {
    gem = createManifoldFromGemGeometry(wasm, geometry);
    onStage?.('csg-started');

    for (const cutPath of validCutPaths) {
      const cutterGeometry = generateVGrooveCutterGeometry([cutPath], frame, settings);
      cutters.push(createManifoldFromGrooveGeometry(wasm, cutterGeometry));
      onStage?.('cutter-geometry-ready');
    }

    cutterUnion = wasm.Manifold.union(cutters);
    result = gem.subtract(cutterUnion);
    if (result.isEmpty()) {
      throw new Error('Boolean subtraction removed the complete gemstone.');
    }
    if (result.status() !== 'NoError') {
      throw new Error(`Manifold boolean failed: ${result.status()}.`);
    }
    onStage?.('csg-completed');

    onStage?.('domain-conversion-started');
    const nextGeometry = manifoldToGemGeometry(result);
    onStage?.('domain-conversion-completed');
    validateGemGeometry(nextGeometry);
    onStage?.('geometry-validated');

    return {
      geometry: nextGeometry,
      cutPathCount: validCutPaths.length,
      trianglesBefore: geometry.triangles.length,
      trianglesAfter: nextGeometry.triangles.length,
    };
  } finally {
    result?.delete();
    cutterUnion?.delete();
    cutters.forEach((cutter) => cutter.delete());
    gem?.delete();
  }
}

async function getManifoldModule() {
  manifoldModulePromise ??= Module().then((wasm) => {
    wasm.setup();
    return wasm;
  });
  return manifoldModulePromise;
}

function createManifoldFromGemGeometry(wasm: ManifoldToplevel, geometry: GemGeometry) {
  return createManifold(wasm, geometry.vertices, geometry.triangles);
}

function createManifoldFromGrooveGeometry(wasm: ManifoldToplevel, geometry: GroovePreviewGeometry) {
  return createManifold(wasm, geometry.vertices, geometry.triangles);
}

function createManifold(
  wasm: ManifoldToplevel,
  vertices: readonly Vec3[],
  triangles: readonly { readonly a: number; readonly b: number; readonly c: number }[],
) {
  const vertProperties = new Float32Array(vertices.length * 3);
  vertices.forEach((vertex, index) => {
    vertProperties[index * 3] = vertex.x;
    vertProperties[index * 3 + 1] = vertex.y;
    vertProperties[index * 3 + 2] = vertex.z;
  });

  const triVerts = new Uint32Array(triangles.length * 3);
  triangles.forEach((triangle, index) => {
    triVerts[index * 3] = triangle.a;
    triVerts[index * 3 + 1] = triangle.b;
    triVerts[index * 3 + 2] = triangle.c;
  });

  return new wasm.Manifold(new wasm.Mesh({ numProp: 3, vertProperties, triVerts }));
}

function manifoldToGemGeometry(manifold: ManifoldSolid) {
  const mesh = manifold.getMesh();
  const canonicalVertices = createCanonicalVertexMap(
    mesh.vertProperties.length / mesh.numProp,
    mesh.mergeFromVert,
    mesh.mergeToVert,
  );
  const compactIndexByCanonical = new Map<number, number>();
  const vertices: Vec3[] = [];
  const compactIndex = (index: number) => {
    const canonical = canonicalVertices[index];
    const existing = compactIndexByCanonical.get(canonical);
    if (existing !== undefined) {
      return existing;
    }
    const next = vertices.length;
    vertices.push({
      x: mesh.vertProperties[canonical * mesh.numProp],
      y: mesh.vertProperties[canonical * mesh.numProp + 1],
      z: mesh.vertProperties[canonical * mesh.numProp + 2],
    });
    compactIndexByCanonical.set(canonical, next);
    return next;
  };

  const triangles: IndexedTriangle[] = [];
  for (let index = 0; index + 2 < mesh.triVerts.length; index += 3) {
    triangles.push({
      a: compactIndex(mesh.triVerts[index]),
      b: compactIndex(mesh.triVerts[index + 1]),
      c: compactIndex(mesh.triVerts[index + 2]),
    });
  }

  return createGemGeometryFromIndexedMesh(vertices, triangles);
}

function createCanonicalVertexMap(
  vertexCount: number,
  mergeFrom: Uint32Array,
  mergeTo: Uint32Array,
) {
  const parent = Uint32Array.from({ length: vertexCount }, (_, index) => index);
  const find = (index: number): number => {
    let root = index;
    while (parent[root] !== root) {
      root = parent[root];
    }
    while (parent[index] !== index) {
      const next = parent[index];
      parent[index] = root;
      index = next;
    }
    return root;
  };

  for (let index = 0; index < mergeFrom.length; index += 1) {
    const fromRoot = find(mergeFrom[index]);
    const toRoot = find(mergeTo[index]);
    if (fromRoot !== toRoot) {
      parent[fromRoot] = toRoot;
    }
  }

  for (let index = 0; index < vertexCount; index += 1) {
    parent[index] = find(index);
  }
  return parent;
}
