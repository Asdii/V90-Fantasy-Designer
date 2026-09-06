export interface GemMaterial {
  readonly id: string;
  readonly name: string;
  readonly refractiveIndex: number;
  readonly color: string;
  readonly transmission: number;
  readonly roughness: number;
  readonly dispersion?: number;
}

export const gemMaterialPresets: Record<string, GemMaterial> = {
  quartz: {
    id: 'quartz',
    name: 'Quartz',
    refractiveIndex: 1.544,
    color: '#d9f3ff',
    transmission: 0.92,
    roughness: 0.05,
  },
  sapphire: {
    id: 'sapphire',
    name: 'Sapphire',
    refractiveIndex: 1.76,
    color: '#7ea7ff',
    transmission: 0.86,
    roughness: 0.035,
  },
  topaz: {
    id: 'topaz',
    name: 'Topaz',
    refractiveIndex: 1.61,
    color: '#ffe0a3',
    transmission: 0.9,
    roughness: 0.045,
  },
  spinel: {
    id: 'spinel',
    name: 'Spinel',
    refractiveIndex: 1.718,
    color: '#ffd3e7',
    transmission: 0.88,
    roughness: 0.04,
  },
  cubicZirconia: {
    id: 'cubicZirconia',
    name: 'Cubic Zirconia',
    refractiveIndex: 2.15,
    color: '#f2fbff',
    transmission: 0.93,
    roughness: 0.025,
  },
  custom: {
    id: 'custom',
    name: 'Custom',
    refractiveIndex: 1.544,
    color: '#d9f3ff',
    transmission: 0.9,
    roughness: 0.05,
  },
};

export function createCustomGemMaterial(base: GemMaterial, refractiveIndex: number, color: string, transmission: number): GemMaterial {
  return {
    ...base,
    id: 'custom',
    name: 'Custom',
    refractiveIndex,
    color,
    transmission,
  };
}
