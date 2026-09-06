import * as THREE from 'three';

export type BackgroundMode = 'black' | 'darkGray' | 'lightGray' | 'white' | 'neutral';

export const backgroundColors: Record<BackgroundMode, string> = {
  black: '#000000',
  darkGray: '#202327',
  lightGray: '#d6d8dc',
  white: '#ffffff',
  neutral: '#b9bec5',
};

export function toThreeColor(mode: BackgroundMode): THREE.Color {
  return new THREE.Color(backgroundColors[mode]);
}
