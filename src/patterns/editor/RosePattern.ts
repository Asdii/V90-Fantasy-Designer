import { createPolylinePrimitive, type PolylinePrimitive, type PrimitiveRole, type Vec2 } from '../model/PatternModel';

export interface RosePatternOptions {
  readonly petals: number;
  readonly radius: number;
  readonly layers: number;
  readonly rotationDeg: number;
  readonly center?: Vec2;
  readonly role?: PrimitiveRole;
}

/** Creates classic polar rose curves r = a*cos(n*theta), discretized as cut-ready polylines. */
export function createRosePatternPrimitives(options: RosePatternOptions): PolylinePrimitive[] {
  const petals = Math.max(3, Math.round(options.petals));
  const layers = Math.max(1, Math.min(6, Math.round(options.layers)));
  const radius = Math.max(0.001, options.radius);
  const center = options.center ?? { x: 0, y: 0 };
  const role = options.role ?? 'pattern';
  const order = petals % 2 === 0 ? petals / 2 : petals;
  const endAngle = petals % 2 === 0 ? Math.PI * 2 : Math.PI;
  const sampleCount = Math.max(96, petals * 32);

  return Array.from({ length: layers }, (_, layerIndex) => {
    const layerScale = (layerIndex + 1) / layers;
    const phase = (options.rotationDeg + (layerIndex * 180) / petals) * Math.PI / 180;
    const points = Array.from({ length: sampleCount }, (_unused, index) => {
      const theta = (index / sampleCount) * endAngle;
      const radial = radius * layerScale * Math.cos(order * theta);
      return {
        x: center.x + radial * Math.cos(theta + phase),
        y: center.y + radial * Math.sin(theta + phase),
      };
    });
    return createPolylinePrimitive(points, true, role);
  });
}
