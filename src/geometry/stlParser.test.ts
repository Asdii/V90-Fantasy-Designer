import { describe, expect, it } from 'vitest';
import { parseStl } from './stlParser';

describe('STL parser', () => {
  it('parses ASCII STL into GemGeometry', () => {
    const ascii = `solid test
facet normal 0 0 0
  outer loop
    vertex 0 0 0
    vertex 1 0 0
    vertex 0 1 0
  endloop
endfacet
endsolid test`;

    const geometry = parseStl(new TextEncoder().encode(ascii).buffer);

    expect(geometry.units).toBe('millimeters');
    expect(geometry.vertices).toHaveLength(3);
    expect(geometry.triangles).toHaveLength(1);
    expect(geometry.triangles[0].normal.z).toBeCloseTo(1);
  });

  it('parses binary STL into GemGeometry', () => {
    const buffer = new ArrayBuffer(84 + 50);
    const view = new DataView(buffer);
    view.setUint32(80, 1, true);
    let offset = 84 + 12;
    for (const value of [0, 0, 0, 1, 0, 0, 0, 1, 0]) {
      view.setFloat32(offset, value, true);
      offset += 4;
    }

    const geometry = parseStl(buffer);

    expect(geometry.vertices).toHaveLength(3);
    expect(geometry.triangles).toHaveLength(1);
    expect(geometry.boundingBox.size).toEqual({ x: 1, y: 1, z: 0 });
  });
});
