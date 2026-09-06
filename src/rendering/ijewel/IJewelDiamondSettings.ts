import type { GemMaterial } from '../../materials/GemMaterial';

export interface IJewelDiamondSettings {
  readonly isDiamond: true;
  readonly color: string;
  readonly refractiveIndex: number;
  readonly transmission: number;
  readonly reflectivity: number;
  readonly rayBounces: number;
  readonly dispersion: number;
  readonly envMapIntensity: number;
  readonly diamondOrientedEnvMap: number;
  readonly absorptionFactor: number;
  readonly gammaFactor: number;
  readonly geometryFactor: number;
  readonly squashFactor: number;
}

export function createIJewelDiamondSettings(material: GemMaterial): IJewelDiamondSettings {
  return {
    isDiamond: true,
    color: material.color,
    refractiveIndex: material.refractiveIndex,
    transmission: 1,
    reflectivity: 0.1,
    rayBounces: 6,
    dispersion: material.dispersion ?? 0,
    envMapIntensity: 7,
    diamondOrientedEnvMap: 100,
    absorptionFactor: 1,
    gammaFactor: 1,
    geometryFactor: 1,
    squashFactor: 1,
  };
}
