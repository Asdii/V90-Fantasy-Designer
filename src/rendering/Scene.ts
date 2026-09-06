import * as THREE from 'three';

export type LightingPreset = 'studioLight' | 'darkStudio' | 'neutral';

export function applyStudioLighting(scene: THREE.Scene, preset: LightingPreset) {
  for (const child of [...scene.children]) {
    if (child.userData.lightingPresetObject) {
      scene.remove(child);
      if (child instanceof THREE.Light) {
        child.dispose();
      }
    }
  }

  const config = lightingConfigs[preset];
  const ambient = new THREE.HemisphereLight(config.skyColor, config.groundColor, config.ambientIntensity);
  ambient.userData.lightingPresetObject = true;
  scene.add(ambient);

  for (const lightConfig of config.lights) {
    const light = new THREE.DirectionalLight(lightConfig.color, lightConfig.intensity);
    light.position.set(lightConfig.position[0], lightConfig.position[1], lightConfig.position[2]);
    light.userData.lightingPresetObject = true;
    scene.add(light);
  }
}

const lightingConfigs = {
  studioLight: {
    skyColor: 0xffffff,
    groundColor: 0xb8c0cc,
    ambientIntensity: 0.9,
    lights: [
      { color: 0xffffff, intensity: 2.4, position: [4, 6, 5] },
      { color: 0x9fc5ff, intensity: 1.1, position: [-5, 3, -4] },
      { color: 0xfff0d0, intensity: 0.7, position: [0, -4, 5] },
    ],
  },
  darkStudio: {
    skyColor: 0x273447,
    groundColor: 0x07090c,
    ambientIntensity: 0.45,
    lights: [
      { color: 0xffffff, intensity: 2.8, position: [4, 6, 5] },
      { color: 0x70a3ff, intensity: 0.9, position: [-4, 2, -5] },
    ],
  },
  neutral: {
    skyColor: 0xe8edf4,
    groundColor: 0x8d969f,
    ambientIntensity: 0.7,
    lights: [
      { color: 0xffffff, intensity: 1.8, position: [5, 5, 5] },
      { color: 0xffffff, intensity: 0.7, position: [-4, 2, -3] },
    ],
  },
} satisfies Record<LightingPreset, {
  readonly skyColor: number;
  readonly groundColor: number;
  readonly ambientIntensity: number;
  readonly lights: readonly {
    readonly color: number;
    readonly intensity: number;
    readonly position: readonly number[];
  }[];
}>;
