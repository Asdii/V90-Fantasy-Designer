import * as THREE from 'three';
import type { Facet } from '../geometry/Facet';
import type { FacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import type { Vec3 } from '../geometry/GemGeometry';
import { isPointInsideFacetLocal } from '../geometry/PointInPolygon';
import { distancePointToPlane } from '../geometry/Plane';
import { worldToLocal } from '../geometry/CoordinateTransforms';
import type { AppCamera } from '../rendering/CameraSystem';
import type { Vec2 } from '../patterns/Pattern';

export function pickLocalPointOnFacetPlane(
  clientX: number,
  clientY: number,
  canvas: HTMLCanvasElement,
  camera: AppCamera,
  facet: Facet,
  localGeometry: FacetLocalGeometry,
): Vec2 | undefined {
  const rect = canvas.getBoundingClientRect();
  const ndc = new THREE.Vector2(
    ((clientX - rect.left) / rect.width) * 2 - 1,
    -(((clientY - rect.top) / rect.height) * 2 - 1),
  );
  const raycaster = new THREE.Raycaster();
  raycaster.setFromCamera(ndc, camera);
  const origin = fromThree(raycaster.ray.origin);
  const direction = fromThree(raycaster.ray.direction);
  const denominator = dotPlaneNormalDirection(facet.normal, direction);

  if (Math.abs(denominator) < 1e-10) {
    return undefined;
  }

  const t = -distancePointToPlane(origin, facet.plane) / denominator;
  if (t < 0) {
    return undefined;
  }

  const worldPoint = {
    x: origin.x + direction.x * t,
    y: origin.y + direction.y * t,
    z: origin.z + direction.z * t,
  };
  const local = worldToLocal(localGeometry.frame, worldPoint);
  const point = { u: local.u, v: local.v };
  return isPointInsideFacetLocal(point, localGeometry.boundary) ? point : undefined;
}

function dotPlaneNormalDirection(normal: Vec3, direction: Vec3) {
  return normal.x * direction.x + normal.y * direction.y + normal.z * direction.z;
}

function fromThree(value: THREE.Vector3): Vec3 {
  return { x: value.x, y: value.y, z: value.z };
}
