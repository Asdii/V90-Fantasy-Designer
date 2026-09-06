import type { GemGeometry } from '../geometry/GemGeometry';
import type { FacetPatternMap } from '../patterns/Pattern';
import type { DesignPattern } from '../patterns/model/PatternModel';
import type { PatternPlacement, WorldCutPath } from '../patterns/placement/PatternPlacement';
import type { CutHelperSnapshot, VGrooveSettings } from '../grooves';

export interface CutOperation {
  readonly id: string;
  readonly facetId: number;
  readonly patternSnapshot: DesignPattern;
  readonly placement: PatternPlacement;
  readonly grooveSettings: VGrooveSettings;
  readonly facetNormal: GemGeometry['vertices'][number];
  readonly worldCutPaths: readonly WorldCutPath[];
  readonly cutPathCount: number;
  readonly cutHelper: CutHelperSnapshot;
}

export interface GemProject {
  readonly version: number;
  readonly source?: {
    readonly filename: string;
  };
  readonly sourceGeometry?: GemGeometry;
  readonly geometry?: GemGeometry;
  readonly cutOperations: readonly CutOperation[];
  readonly patterns: FacetPatternMap;
  readonly designPattern?: DesignPattern;
}
