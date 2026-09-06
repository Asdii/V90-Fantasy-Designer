import type { CameraSnapshot } from '../rendering/cameraViews';
import type { Vec2 } from '../patterns/Pattern';

interface StatusBarProps {
  readonly camera: CameraSnapshot;
  readonly objectCount: number;
  readonly fps: number;
  readonly localCursor?: Vec2;
}

function formatVec3(value: readonly [number, number, number]) {
  return value.map((component) => component.toFixed(2)).join(', ');
}

export function StatusBar({ camera, objectCount, fps, localCursor }: StatusBarProps) {
  return (
    <footer className="statusBar">
      <span>Camera position: {formatVec3(camera.position)} mm</span>
      <span>Target: {formatVec3(camera.target)} mm</span>
      <span>U: {localCursor ? localCursor.u.toFixed(3) : '-' } mm</span>
      <span>V: {localCursor ? localCursor.v.toFixed(3) : '-' } mm</span>
      <span>Objects: {objectCount}</span>
      <span>FPS: {fps}</span>
    </footer>
  );
}
