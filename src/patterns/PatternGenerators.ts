import type { Pattern, Vec2 } from './Pattern';
import { createSegment, identityPatternTransform } from './Pattern';
import { createCircleSegments, createPolylineSegments } from './PatternGeometry';

export type GeneratorType =
  | 'regularPolygon'
  | 'star'
  | 'starPolygon'
  | 'radialLines'
  | 'concentricPolygons'
  | 'concentricCircles'
  | 'simpleRosette';

export interface PatternGenerator<TParameters> {
  generate(params: TParameters): Pattern;
}

export interface RegularPolygonParams {
  readonly sides: number;
  readonly radius: number;
  readonly rotationDeg: number;
}

export interface StarParams {
  readonly points: number;
  readonly outerRadius: number;
  readonly innerRadius: number;
  readonly rotationDeg: number;
}

export interface StarPolygonParams {
  readonly points: number;
  readonly step: number;
  readonly radius: number;
  readonly rotationDeg: number;
}

export interface RadialLinesParams {
  readonly count: number;
  readonly innerRadius: number;
  readonly outerRadius: number;
  readonly rotationDeg: number;
}

export interface ConcentricPolygonParams {
  readonly sides: number;
  readonly count: number;
  readonly innerRadius: number;
  readonly outerRadius: number;
  readonly rotationDeg: number;
}

export interface ConcentricCircleParams {
  readonly count: number;
  readonly innerRadius: number;
  readonly outerRadius: number;
}

export interface SimpleRosetteParams {
  readonly order: number;
  readonly outerRadius: number;
  readonly innerRadius: number;
  readonly rotationDeg: number;
  readonly connectionStep: number;
}

export const RegularPolygonGenerator: PatternGenerator<RegularPolygonParams> = {
  generate: (params) =>
    createGeneratedPattern(
      'regularPolygon',
      { ...params },
      createPolylineSegments(regularPoints(params.sides, params.radius, params.rotationDeg), true),
    ),
};

export const StarGenerator: PatternGenerator<StarParams> = {
  generate: (params) => {
    const vertices = Array.from({ length: params.points * 2 }, (_, index) => {
      const radius = index % 2 === 0 ? params.outerRadius : params.innerRadius;
      const angle = params.rotationDeg + (index / (params.points * 2)) * 360;
      return polarPoint(radius, angle);
    });
    return createGeneratedPattern('star', { ...params }, createPolylineSegments(vertices, true));
  },
};

export const StarPolygonGenerator: PatternGenerator<StarPolygonParams> = {
  generate: (params) => {
    const points = regularPoints(params.points, params.radius, params.rotationDeg);
    const segments = points.map((point, index) => createSegment(point, points[(index + params.step) % points.length]));
    return createGeneratedPattern('starPolygon', { ...params }, segments);
  },
};

export const RadialLinesGenerator: PatternGenerator<RadialLinesParams> = {
  generate: (params) => {
    const segments = Array.from({ length: params.count }, (_, index) => {
      const angle = params.rotationDeg + (index / params.count) * 360;
      return createSegment(polarPoint(params.innerRadius, angle), polarPoint(params.outerRadius, angle));
    });
    return createGeneratedPattern('radialLines', { ...params }, segments);
  },
};

export const ConcentricPolygonGenerator: PatternGenerator<ConcentricPolygonParams> = {
  generate: (params) => {
    const radii = distributedRadii(params.count, params.innerRadius, params.outerRadius);
    const segments = radii.flatMap((radius) =>
      createPolylineSegments(regularPoints(params.sides, radius, params.rotationDeg), true),
    );
    return createGeneratedPattern('concentricPolygons', { ...params }, segments);
  },
};

export const ConcentricCircleGenerator: PatternGenerator<ConcentricCircleParams> = {
  generate: (params) => {
    const radii = distributedRadii(params.count, params.innerRadius, params.outerRadius);
    const segments = radii.flatMap((radius) => createCircleSegments({ u: 0, v: 0 }, { u: radius, v: 0 }, 64));
    return createGeneratedPattern('concentricCircles', { ...params }, segments);
  },
};

export const SimpleRosetteGenerator: PatternGenerator<SimpleRosetteParams> = {
  generate: (params) => {
    const outer = regularPoints(params.order, params.outerRadius, params.rotationDeg);
    const inner = regularPoints(params.order, params.innerRadius, params.rotationDeg + 180 / params.order);
    const segments = outer.flatMap((point, index) => [
      createSegment(point, outer[(index + params.connectionStep) % outer.length]),
      createSegment(point, inner[index]),
      createSegment(inner[index], inner[(index + params.connectionStep) % inner.length]),
    ]);
    return createGeneratedPattern('simpleRosette', { ...params }, segments);
  },
};

export function generatePattern(type: GeneratorType, params: Record<string, number>): Pattern {
  switch (type) {
    case 'regularPolygon':
      return RegularPolygonGenerator.generate({
        sides: Math.max(3, Math.round(params.sides)),
        radius: Math.max(0, params.radius),
        rotationDeg: params.rotationDeg,
      });
    case 'star':
      return StarGenerator.generate({
        points: Math.max(2, Math.round(params.points)),
        outerRadius: Math.max(0, params.outerRadius),
        innerRadius: Math.max(0, params.innerRadius),
        rotationDeg: params.rotationDeg,
      });
    case 'starPolygon':
      return StarPolygonGenerator.generate({
        points: Math.max(3, Math.round(params.points)),
        step: Math.max(1, Math.round(params.step)),
        radius: Math.max(0, params.radius),
        rotationDeg: params.rotationDeg,
      });
    case 'radialLines':
      return RadialLinesGenerator.generate({
        count: Math.max(1, Math.round(params.count)),
        innerRadius: Math.max(0, params.innerRadius),
        outerRadius: Math.max(0, params.outerRadius),
        rotationDeg: params.rotationDeg,
      });
    case 'concentricPolygons':
      return ConcentricPolygonGenerator.generate({
        sides: Math.max(3, Math.round(params.sides)),
        count: Math.max(1, Math.round(params.count)),
        innerRadius: Math.max(0, params.innerRadius),
        outerRadius: Math.max(0, params.outerRadius),
        rotationDeg: params.rotationDeg,
      });
    case 'concentricCircles':
      return ConcentricCircleGenerator.generate({
        count: Math.max(1, Math.round(params.count)),
        innerRadius: Math.max(0, params.innerRadius),
        outerRadius: Math.max(0, params.outerRadius),
      });
    case 'simpleRosette':
      return SimpleRosetteGenerator.generate({
        order: Math.max(3, Math.round(params.order)),
        outerRadius: Math.max(0, params.outerRadius),
        innerRadius: Math.max(0, params.innerRadius),
        rotationDeg: params.rotationDeg,
        connectionStep: Math.max(1, Math.round(params.connectionStep)),
      });
  }
}

function createGeneratedPattern(
  generatorType: GeneratorType,
  parameters: Record<string, number>,
  segments: Pattern['segments'],
): Pattern {
  return {
    id: `generated-${generatorType}-${crypto.randomUUID()}`,
    name: generatorType,
    segments,
    transform: identityPatternTransform,
    generated: { generatorType, parameters },
  };
}

function regularPoints(sides: number, radius: number, rotationDeg: number): Vec2[] {
  return Array.from({ length: sides }, (_, index) => polarPoint(radius, rotationDeg + (index / sides) * 360));
}

function polarPoint(radius: number, angleDeg: number): Vec2 {
  const radians = (angleDeg * Math.PI) / 180;
  return { u: Math.cos(radians) * radius, v: Math.sin(radians) * radius };
}

function distributedRadii(count: number, innerRadius: number, outerRadius: number): number[] {
  if (count === 1) {
    return [outerRadius];
  }
  return Array.from({ length: count }, (_, index) => innerRadius + ((outerRadius - innerRadius) * index) / (count - 1));
}
