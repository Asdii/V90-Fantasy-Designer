import * as THREE from 'three';
import { localToWorld } from '../geometry/CoordinateTransforms';
import type { FacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import type { GemGeometry } from '../geometry/GemGeometry';
import { clipPatternToFacet, type PatternPlacement } from '../patterns/placement/PatternPlacement';
import type { DesignPattern } from '../patterns/model/PatternModel';
import type { LineSegment2D } from '../patterns/Pattern';

export class PlacedPatternRenderer {
  private group = new THREE.Group();

  constructor(private readonly scene: THREE.Scene) {
    this.group.name = 'Placed pattern overlay';
    this.scene.add(this.group);
  }

  render(
    geometry: GemGeometry | undefined,
    localGeometry: FacetLocalGeometry | undefined,
    pattern: DesignPattern | undefined,
    placement: PatternPlacement | undefined,
    showOutsideFacet: boolean,
  ) {
    this.clearGroup();
    if (!geometry || !localGeometry || !pattern || !placement || pattern.primitives.length === 0) {
      return;
    }

    const diagonal = new THREE.Vector3(
      geometry.boundingBox.size.x,
      geometry.boundingBox.size.y,
      geometry.boundingBox.size.z,
    ).length();
    const offset = Math.max(diagonal * 0.002, 0.01);
    const clipped = clipPatternToFacet(pattern, placement, localGeometry.boundary);

    for (const segment of clipped.insideSegments) {
      this.group.add(createSegmentLine(localGeometry, segment, offset, 0x25d0ff, 0.95));
    }
    if (showOutsideFacet) {
      for (const segment of clipped.outsideSegments) {
        this.group.add(createSegmentLine(localGeometry, segment, offset, 0x7c8792, 0.26));
      }
    }
  }

  dispose() {
    this.clearGroup();
    this.scene.remove(this.group);
  }

  private clearGroup() {
    for (const child of [...this.group.children]) {
      this.group.remove(child);
      if (child instanceof THREE.Line) {
        child.geometry.dispose();
        disposeMaterial(child.material);
      }
    }
  }
}

function createSegmentLine(
  localGeometry: FacetLocalGeometry,
  segment: LineSegment2D,
  offsetNormal: number,
  color: number,
  opacity: number,
) {
  const start = localToWorld(localGeometry.frame, segment.start.u, segment.start.v, offsetNormal);
  const end = localToWorld(localGeometry.frame, segment.end.u, segment.end.v, offsetNormal);
  const line = new THREE.Line(
    new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(start.x, start.y, start.z),
      new THREE.Vector3(end.x, end.y, end.z),
    ]),
    new THREE.LineBasicMaterial({ color, transparent: true, opacity }),
  );
  line.name = 'Placed pattern segment';
  return line;
}

function disposeMaterial(material: THREE.Material | THREE.Material[]) {
  if (Array.isArray(material)) {
    material.forEach((item) => item.dispose?.());
    return;
  }
  material.dispose?.();
}
