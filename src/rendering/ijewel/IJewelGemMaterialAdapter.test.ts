import { describe, expect, it } from 'vitest';
import { gemMaterialPresets } from '../../materials/GemMaterial';
import { createIJewelDiamondSettings } from './IJewelDiamondSettings';

describe('iJewel diamond settings', () => {
  it('passes the domain IOR into the multi-bounce diamond shader', () => {
    const settings = createIJewelDiamondSettings(gemMaterialPresets.quartz);
    expect(settings.refractiveIndex).toBe(1.544);
    expect(settings.transmission).toBe(1);
    expect(settings.rayBounces).toBe(6);
  });

  it('keeps high-IOR materials physically distinct', () => {
    const quartz = createIJewelDiamondSettings(gemMaterialPresets.quartz);
    const cubicZirconia = createIJewelDiamondSettings(gemMaterialPresets.cubicZirconia);
    expect(cubicZirconia.refractiveIndex).toBeGreaterThan(quartz.refractiveIndex);
  });
});
