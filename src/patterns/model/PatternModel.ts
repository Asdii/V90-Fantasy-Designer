export interface Vec2 {
  readonly x: number;
  readonly y: number;
}

export type PrimitiveRole = 'pattern' | 'construction';

export interface PrimitiveBase {
  readonly id: string;
  readonly role: PrimitiveRole;
}

export interface LinePrimitive extends PrimitiveBase {
  readonly type: 'line';
  readonly start: Vec2;
  readonly end: Vec2;
}

export interface PolylinePrimitive extends PrimitiveBase {
  readonly type: 'polyline';
  readonly points: readonly Vec2[];
  readonly closed: boolean;
}

export interface CirclePrimitive extends PrimitiveBase {
  readonly type: 'circle';
  readonly center: Vec2;
  readonly radius: number;
}

export interface ArcPrimitive extends PrimitiveBase {
  readonly type: 'arc';
  readonly center: Vec2;
  readonly radius: number;
  readonly startAngleDeg: number;
  readonly endAngleDeg: number;
}

export type PatternPrimitive = LinePrimitive | PolylinePrimitive | CirclePrimitive | ArcPrimitive;

export interface DesignPattern {
  readonly id: string;
  readonly name: string;
  readonly primitives: readonly PatternPrimitive[];
}

export interface CutPath {
  readonly points: readonly Vec2[];
  readonly closed: boolean;
}

export function createEmptyDesignPattern(): DesignPattern {
  return {
    id: `design-pattern-${crypto.randomUUID()}`,
    name: 'Untitled Pattern',
    primitives: [],
  };
}

export function createLinePrimitive(start: Vec2, end: Vec2, role: PrimitiveRole = 'pattern'): LinePrimitive {
  return { id: crypto.randomUUID(), type: 'line', role, start, end };
}

export function createPolylinePrimitive(
  points: readonly Vec2[],
  closed: boolean,
  role: PrimitiveRole = 'pattern',
): PolylinePrimitive {
  return { id: crypto.randomUUID(), type: 'polyline', role, points: [...points], closed };
}

export function createCirclePrimitive(center: Vec2, radius: number, role: PrimitiveRole = 'pattern'): CirclePrimitive {
  return { id: crypto.randomUUID(), type: 'circle', role, center, radius: Math.max(0, radius) };
}

export function createArcPrimitive(
  center: Vec2,
  radius: number,
  startAngleDeg: number,
  endAngleDeg: number,
  role: PrimitiveRole = 'pattern',
): ArcPrimitive {
  return { id: crypto.randomUUID(), type: 'arc', role, center, radius: Math.max(0, radius), startAngleDeg, endAngleDeg };
}
