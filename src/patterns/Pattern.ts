export interface Vec2 {
  readonly u: number;
  readonly v: number;
}

export interface LineSegment2D {
  readonly id: string;
  readonly start: Vec2;
  readonly end: Vec2;
}

export interface PatternTransform {
  readonly offsetU: number;
  readonly offsetV: number;
  readonly rotationDeg: number;
  readonly scale: number;
}

export interface GeneratedPatternMetadata {
  readonly generatorType: string;
  readonly parameters: Record<string, number | string>;
}

export interface Pattern {
  readonly id: string;
  readonly name: string;
  readonly segments: readonly LineSegment2D[];
  readonly transform: PatternTransform;
  readonly generated?: GeneratedPatternMetadata;
}

export type FacetPatternMap = Record<number, Pattern>;

export type PatternTool = 'select' | 'line' | 'polyline' | 'polygon' | 'rectangle' | 'circle';

export type GridSnapStep = 'off' | '1' | '0.5' | '0.1';

export const identityPatternTransform: PatternTransform = {
  offsetU: 0,
  offsetV: 0,
  rotationDeg: 0,
  scale: 1,
};

export function createEmptyPattern(facetId: number): Pattern {
  return {
    id: `pattern-facet-${facetId}`,
    name: `Facet ${facetId} pattern`,
    segments: [],
    transform: identityPatternTransform,
  };
}

export function createSegment(start: Vec2, end: Vec2): LineSegment2D {
  return {
    id: crypto.randomUUID(),
    start,
    end,
  };
}
