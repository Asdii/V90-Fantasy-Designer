import { validateGemGeometry } from '../geometry/GeometryValidation';
import type { GemGeometry } from '../geometry/GemGeometry';
import { subtractVGroovesFromGemGeometry } from '../rendering/csg/VGrooveCsg';
import type { CutOperation } from './GemProject';

export async function rebuildWorkingGemGeometry(
  sourceGeometry: GemGeometry,
  operations: readonly CutOperation[],
) {
  let rebuilt = sourceGeometry;
  for (const operation of operations) {
    rebuilt = (await subtractVGroovesFromGemGeometry(
      rebuilt,
      operation.worldCutPaths,
      { normal: operation.facetNormal },
      operation.grooveSettings,
    )).geometry;
  }
  validateGemGeometry(rebuilt);
  return rebuilt;
}
