import { describe, expect, it } from 'vitest';
import { createPlaceholderGemGeometry } from './createPlaceholderGemGeometry';
import { writeBinaryStl } from './stlWriter';

describe('writeBinaryStl', () => {
  it('exports every triangle from the working geometry', () => {
    const geometry = createPlaceholderGemGeometry();
    const buffer = writeBinaryStl(geometry);
    expect(buffer.byteLength).toBe(84 + geometry.triangles.length * 50);
    expect(new DataView(buffer).getUint32(80, true)).toBe(12);
  });
});
