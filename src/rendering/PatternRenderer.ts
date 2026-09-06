import * as THREE from 'three';
import type { Facet } from '../geometry/Facet';
import { localToWorld } from '../geometry/CoordinateTransforms';
import type { FacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import type { GemGeometry } from '../geometry/GemGeometry';
import type { LineSegment2D, Pattern, Vec2 } from '../patterns/Pattern';
import { clipSegmentToFacetPolygon } from '../patterns/PatternClipping';
import { transformSegment } from '../patterns/PatternGeometry';

export interface PatternRenderState {
  readonly previewSegments?: readonly LineSegment2D[];
  readonly selectedSegmentId?: string;
  readonly showOutsideFacet?: boolean;
}

export class PatternRenderer {
  private group = new THREE.Group();

  constructor(private readonly scene: THREE.Scene) {
    this.group.name = 'Pattern overlay';
    this.scene.add(this.group);
  }

  render(
    geometry: GemGeometry | undefined,
    facet: Facet | undefined,
    localGeometry: FacetLocalGeometry | undefined,
    pattern: Pattern | undefined,
    state: PatternRenderState = {},
  ) {
    this.clearGroup();

    if (!geometry || !facet || !localGeometry) {
      return;
    }

    const diagonal = new THREE.Vector3(
      geometry.boundingBox.size.x,
      geometry.boundingBox.size.y,
      geometry.boundingBox.size.z,
    ).length();
    const offset = Math.max(diagonal * 0.002, 0.01);

    if (pattern) {
      for (const segment of pattern.segments) {
        this.addSegmentWithClipping(localGeometry, transformSegment(segment, pattern.transform), offset, segment.id === state.selectedSegmentId, state.showOutsideFacet ?? true);
        if (segment.id === state.selectedSegmentId) {
          const transformed = transformSegment(segment, pattern.transform);
          this.group.add(createEndpointMarker(localGeometry, transformed.start, offset, 0xffd36e, diagonal));
          this.group.add(createEndpointMarker(localGeometry, transformed.end, offset, 0xffd36e, diagonal));
        }
      }
    }

    for (const segment of state.previewSegments ?? []) {
      this.group.add(createSegmentLine(localGeometry, segment, offset * 1.5, false, 0xffffff, 0.55));
    }
  }

  private addSegmentWithClipping(
    localGeometry: FacetLocalGeometry,
    segment: LineSegment2D,
    offset: number,
    selected: boolean,
    showOutsideFacet: boolean,
  ) {
    const clipped = clipSegmentToFacetPolygon(segment, localGeometry.boundary);
    for (const inside of clipped.inside) {
      this.group.add(createSegmentLine(localGeometry, inside, offset, selected));
    }

    if (showOutsideFacet) {
      for (const outside of clipped.outside) {
        this.group.add(createSegmentLine(localGeometry, outside, offset, selected, 0x6f7b86, 0.28));
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
      } else if (child instanceof THREE.Mesh) {
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
  selected: boolean,
  color = 0x25d0ff,
  opacity = 0.95,
) {
  const start = localToWorld(localGeometry.frame, segment.start.u, segment.start.v, offsetNormal);
  const end = localToWorld(localGeometry.frame, segment.end.u, segment.end.v, offsetNormal);
  const line = new THREE.Line(
    new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(start.x, start.y, start.z),
      new THREE.Vector3(end.x, end.y, end.z),
    ]),
    new THREE.LineBasicMaterial({
      color: selected ? 0xffd36e : color,
      transparent: true,
      opacity,
    }),
  );
  line.name = selected ? 'Selected pattern segment' : 'Pattern segment';
  return line;
}

function createEndpointMarker(
  localGeometry: FacetLocalGeometry,
  point: Vec2,
  offsetNormal: number,
  color: number,
  diagonal: number,
) {
  const world = localToWorld(localGeometry.frame, point.u, point.v, offsetNormal * 1.2);
  const marker = new THREE.Mesh(
    new THREE.SphereGeometry(Math.max(diagonal * 0.008, 0.025), 12, 8),
    new THREE.MeshBasicMaterial({ color }),
  );
  marker.position.set(world.x, world.y, world.z);
  marker.name = 'Pattern endpoint marker';
  return marker;
}

function disposeMaterial(material: THREE.Material | THREE.Material[]) {
  if (Array.isArray(material)) {
    material.forEach((item) => item.dispose?.());
    return;
  }

  material.dispose?.();
}
