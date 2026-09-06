import { Color, MeshStandardMaterial2 } from 'webgi';
import type { GemMaterial } from '../../materials/GemMaterial';

/** Initial WebGi material replaced in-place by DiamondPlugin.makeDiamondMesh. */
export function createIJewelBaseMaterial(material: GemMaterial, vertexColors = false) {
  const result = new MeshStandardMaterial2({
    color: new Color(material.color),
    metalness: 0,
    roughness: Math.min(material.roughness, 0.04),
    flatShading: true,
    vertexColors,
  });
  return result;
}

/** Opaque faceted material for positioning patterns and inspecting cut geometry. */
export function createIJewelSetupMaterial(vertexColors = false) {
  const result = new MeshStandardMaterial2({
    color: new Color(vertexColors ? '#ffffff' : '#8fa6b8'),
    metalness: 0,
    roughness: 0.72,
    flatShading: true,
    vertexColors,
    transparent: false,
    opacity: 1,
  });
  Object.assign(result, { envMapIntensity: 0 });
  return result;
}
