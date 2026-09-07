export type CameraViewName =
  | 'reset'
  | 'top'
  | 'bottom'
  | 'front'
  | 'back'
  | 'left'
  | 'right';

export interface CameraSnapshot {
  readonly position: readonly [number, number, number];
  readonly target: readonly [number, number, number];
}
