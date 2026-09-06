import { describe, expect, it } from 'vitest';
import { dot, normalize } from '../../geometry/vectorMath';
import { fresnelDielectric, refractDirection } from './OpticalMath';

describe('Optical dielectric math', () => {
  it('refracts air into quartz according to Snell law', () => {
    const incidentAngle = 30 * Math.PI / 180;
    const incident = normalize({ x: Math.sin(incidentAngle), y: 0, z: -Math.cos(incidentAngle) });
    const refracted = refractDirection(incident, { x: 0, y: 0, z: 1 }, 1, 1.544);

    expect(refracted).toBeDefined();
    const transmittedAngle = Math.acos(dot(refracted!, { x: 0, y: 0, z: -1 }));
    expect(Math.sin(transmittedAngle)).toBeCloseTo(Math.sin(incidentAngle) / 1.544);
  });

  it('does not bend at normal incidence', () => {
    const refracted = refractDirection({ x: 0, y: 0, z: -1 }, { x: 0, y: 0, z: 1 }, 1, 1.544);

    expect(refracted).toMatchObject({ x: 0, y: 0, z: -1 });
  });

  it('returns no transmitted ray under total internal reflection', () => {
    const angle = 50 * Math.PI / 180;
    const incident = normalize({ x: Math.sin(angle), y: 0, z: Math.cos(angle) });

    expect(refractDirection(incident, { x: 0, y: 0, z: 1 }, 1.544, 1)).toBeUndefined();
  });

  it('matches dielectric R0 at normal incidence', () => {
    const fresnel = fresnelDielectric({ x: 0, y: 0, z: -1 }, { x: 0, y: 0, z: 1 }, 1, 1.544);
    const r0 = ((1 - 1.544) / (1 + 1.544)) ** 2;

    expect(fresnel).toBeCloseTo(r0);
  });
});
