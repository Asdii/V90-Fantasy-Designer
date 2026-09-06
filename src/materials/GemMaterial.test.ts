import { describe, expect, it } from 'vitest';
import { gemMaterialPresets } from './GemMaterial';

describe('gemMaterialPresets', () => {
  it('contains physically meaningful initial refractive indices', () => {
    expect(gemMaterialPresets.quartz.refractiveIndex).toBeCloseTo(1.544);
    expect(gemMaterialPresets.sapphire.refractiveIndex).toBeCloseTo(1.76);
    expect(gemMaterialPresets.topaz.refractiveIndex).toBeCloseTo(1.61);
    expect(gemMaterialPresets.spinel.refractiveIndex).toBeCloseTo(1.718);
    expect(gemMaterialPresets.cubicZirconia.refractiveIndex).toBeCloseTo(2.15);
  });
});
