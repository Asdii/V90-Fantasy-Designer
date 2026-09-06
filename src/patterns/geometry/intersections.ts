import type { LinePrimitive, Vec2 } from '../model/PatternModel';

export function intersectLineSegments(a: LinePrimitive, b: LinePrimitive): Vec2 | undefined {
  const p = a.start;
  const r = { x: a.end.x - a.start.x, y: a.end.y - a.start.y };
  const q = b.start;
  const s = { x: b.end.x - b.start.x, y: b.end.y - b.start.y };
  const denominator = cross(r, s);

  if (Math.abs(denominator) < 1e-12) {
    return undefined;
  }

  const qp = { x: q.x - p.x, y: q.y - p.y };
  const t = cross(qp, s) / denominator;
  const u = cross(qp, r) / denominator;
  if (t < -1e-10 || t > 1 + 1e-10 || u < -1e-10 || u > 1 + 1e-10) {
    return undefined;
  }

  return { x: p.x + r.x * t, y: p.y + r.y * t };
}

export function findLineIntersections(lines: readonly LinePrimitive[]): Vec2[] {
  const intersections: Vec2[] = [];
  for (let a = 0; a < lines.length; a += 1) {
    for (let b = a + 1; b < lines.length; b += 1) {
      const intersection = intersectLineSegments(lines[a], lines[b]);
      if (intersection) {
        intersections.push(intersection);
      }
    }
  }
  return intersections;
}

function cross(a: Vec2, b: Vec2) {
  return a.x * b.y - a.y * b.x;
}
