import { describe, expect, it, vi } from 'vitest';
import fixture from '../../microfantasy/examples/v90-cut-helper.json';
import type { FacetLocalGeometry } from '../geometry/FacetLocalGeometry';
import type { CutOperation } from '../project/GemProject';
import { buildCutHelperSequence } from '../project/CutHelperSequence';
import { calculateCutAngleDeg, calculateLineDistanceFromOriginMm, type CutInstruction } from '../grooves/CutHelper';
import { createMicroFantasyJob } from './MicroFantasyJob';
import { discoverMicroFantasy, MicroFantasyClient, microFantasyBaseUrl } from './MicroFantasyClient';

const reference: FacetLocalGeometry = { frame: { origin: { x: 10, y: 4, z: 0 }, uAxis: { x: 1, y: 0, z: 0 },
  vAxis: { x: 0, y: 1, z: 0 }, normal: { x: 0, y: 0, z: 1 } },
  boundary: fixture.cutHelper.boundary,
  bounds: { minU: -2, maxU: 3, minV: -1, maxV: 2, width: 5, height: 3 } };
function operation(id: string, geometry: FacetLocalGeometry, instructions: CutInstruction[]): CutOperation {
  return { id, facetId: id === 'first' ? 7 : 99, cutHelper: { localGeometry: geometry, instructions, grooveWidthMm: id === 'first' ? .06 : .1 },
    patternSnapshot: { id: 'design', name: 'design', primitives: [] }, placement: { facetId: 7, offsetX: 0, offsetY: 0, rotationDeg: 0, scale: 1 },
    grooveSettings: { includedAngleDeg: 90, depthMm: id === 'first' ? .03 : .05 }, facetNormal: geometry.frame.normal, worldCutPaths: [], cutPathCount: instructions.length };
}
function instruction(i: number, shift = 0): CutInstruction {
  const f = fixture.cutHelper.steps[i];
  const segment = { id: `s${i}`, start: { u: f.segment.start.u - shift, v: f.segment.start.v }, end: { u: f.segment.end.u - shift, v: f.segment.end.v } };
  return { id: segment.id, step: i + 1, angleDeg: calculateCutAngleDeg(segment), distanceFromCenterMm: calculateLineDistanceFromOriginMm(segment),
    depthMm: fixture.steps[i].depth, segment, visibleSegments: [segment] };
}
function exported() {
  const shifted = { ...reference, frame: { ...reference.frame, origin: { x: 11, y: 4, z: 0 } } };
  const sequence = buildCutHelperSequence([operation('first', reference, [instruction(0), instruction(1)]), operation('second', shifted, [instruction(2, 1)])]);
  return createMicroFantasyJob(sequence, { jobId: fixture.jobId, name: fixture.name, machineCenterXmm: 12,
    view: { stepIndex: 2, direction: 'vertical', orientation: 'cut' } });
}

describe('V90 → MicroFantasy shared contract', () => {
  it('discovers through ESP32, deduplicates and verifies actual receiver capabilities', async () => {
    const fetcher = vi.fn<typeof fetch>().mockImplementation(async (input) => {
      if (String(input).includes('/api/v1/apps')) return Response.json({ service: 'microfantasy-machine', api_version: 1,
        apps: ['http://192.168.1.8:8787', 'http://192.168.1.8:8787', 'https://example.com'] });
      return Response.json({ service: 'microfantasy', api_version: 1, accepting_jobs: true, cut_helper_versions: [1] });
    });
    expect(await discoverMicroFantasy('', new AbortController().signal, fetcher)).toEqual(['http://192.168.1.8:8787']);
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(fetcher.mock.calls[0][1]).toMatchObject({ targetAddressSpace: 'local', credentials: 'omit', redirect: 'error' });
  });
  it('uses remembered phone when machine is absent and never sends jobs during discovery', async () => {
    const fetcher = vi.fn<typeof fetch>().mockImplementation(async (input) => {
      if (String(input).includes('/api/v1/apps')) throw new TypeError('offline');
      return Response.json({ service: 'microfantasy', api_version: 1, accepting_jobs: true, cut_helper_versions: [1] });
    });
    expect(await discoverMicroFantasy('192.168.1.9', new AbortController().signal, fetcher)).toEqual(['http://192.168.1.9:8787']);
    expect(fetcher.mock.calls.every(([, init]) => !init?.method || init.method === 'GET')).toBe(true);
  });
  it('exports the exact fixture parsed and rendered by Flutter, including rebased operations', () => {
    expect(exported()).toEqual(fixture);
    expect(exported().steps.map((s) => s.x)).toEqual([12.5, 11.5, 13]);
    expect(exported().cutHelper.steps.map((s) => s.distanceFromCenterMm)).toEqual([.5, .5, 1]);
  });
  it('requires a created sequence and finite center', () => {
    expect(() => createMicroFantasyJob([], { jobId: 'a', name: 'b', view: { stepIndex: 0, direction: 'horizontal', orientation: 'cut' } })).toThrow();
  });
  it('allows LAN addresses and rejects external destinations and credentials', () => {
    expect(microFantasyBaseUrl('192.168.1.20').href).toBe('http://192.168.1.20:8787/');
    expect(microFantasyBaseUrl('http://phone.local:8888/api/v1/jobs').origin).toBe('http://phone.local:8888');
    for (const input of ['https://example.com', 'http://user:pass@192.168.1.2', 'file:///a', 'http://192.168.1.1/other', 'http://10.0.0.1?token=abc']) expect(() => microFantasyBaseUrl(input)).toThrow();
  });
  it('checks capabilities, requests LAN access, then posts the complete job without pairing', async () => {
    const fetcher = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(Response.json({ service: 'microfantasy', api_version: 1, accepting_jobs: true, cut_helper_versions: [1] }))
      .mockResolvedValueOnce(Response.json({ status: 'pending', job_id: fixture.jobId, cut_helper_version: 1 }, { status: 202 }));
    const client = new MicroFantasyClient(microFantasyBaseUrl('192.168.1.2'), fetcher);
    await client.send(exported());
    expect(fetcher).toHaveBeenCalledTimes(2);
    const request = fetcher.mock.calls[1][1]!;
    expect(request).toMatchObject({ method: 'POST', targetAddressSpace: 'local', redirect: 'error', credentials: 'omit' });
    expect(JSON.parse(request.body as string)).toEqual(fixture);
    expect(request.headers).toEqual({ 'Content-Type': 'application/json' });
  });
  it('does not send to old mobile versions or silently accept a mismatching receipt', async () => {
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(Response.json({ service: 'microfantasy', api_version: 1, accepting_jobs: true }));
    await expect(new MicroFantasyClient(microFantasyBaseUrl('127.0.0.1'), fetcher).send(exported())).rejects.toThrow('Update MicroFantasy');
    expect(fetcher).toHaveBeenCalledTimes(1);
  });
  it('shows a useful error for a blocked or unreachable LAN', async () => {
    const warning = vi.spyOn(console, 'warn').mockImplementation(() => {});
    const fetcher = vi.fn<typeof fetch>().mockRejectedValue(new TypeError('Failed to fetch'));
    await expect(new MicroFantasyClient(microFantasyBaseUrl('phone.local'), fetcher).check()).rejects.toThrow('local network access');
    warning.mockRestore();
  });
  it('calls native fetch in its global context, not as a client instance method', async () => {
    vi.stubGlobal('fetch', function (this: unknown) {
      if (this instanceof MicroFantasyClient) throw new TypeError('Illegal invocation');
      return Promise.resolve(Response.json({ service: 'microfantasy', api_version: 1, accepting_jobs: true, cut_helper_versions: [1] }));
    });
    try {
      await expect(new MicroFantasyClient(microFantasyBaseUrl('127.0.0.1')).check()).resolves.toEqual({ maxBytes: 1048576 });
    } finally { vi.unstubAllGlobals(); }
  });
});
