import type { CutHelperStep } from '../grooves/CutHelper';
import { rebaseCutInstruction } from '../grooves/CutHelper';
import type { CutOperation } from './GemProject';

export function buildCutHelperSequence(operations: readonly CutOperation[]): CutHelperStep[] {
  const first = operations[0];
  if (!first) return [];
  const reference = first.cutHelper.localGeometry;
  return operations.flatMap((operation, index) => operation.cutHelper.instructions.map((instruction) => ({
    operationId: operation.id, operationNumber: index + 1, facetId: first.facetId,
    localGeometry: reference,
    instruction: rebaseCutInstruction(instruction, operation.cutHelper.localGeometry, reference),
    grooveWidthMm: operation.cutHelper.grooveWidthMm,
  })));
}
