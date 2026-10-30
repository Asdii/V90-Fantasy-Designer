import type { MicroFantasyJob } from './MicroFantasyJob';

export function microFantasyBaseUrl(input: string): URL {
  const url = new URL(input.trim().includes('://') ? input.trim() : `http://${input.trim()}`);
  const host = url.hostname.toLowerCase();
  const v4 = host.split('.').map(Number);
  const localV4 = v4.length === 4 && v4.every((n) => Number.isInteger(n) && n >= 0 && n <= 255) &&
    (v4[0] === 10 || v4[0] === 127 || (v4[0] === 192 && v4[1] === 168) ||
      (v4[0] === 172 && v4[1] >= 16 && v4[1] <= 31) || (v4[0] === 169 && v4[1] === 254));
  const local = localV4 || host === 'localhost' || host.endsWith('.localhost') || host.endsWith('.local') ||
    host === '[::1]' || /^\[(fc|fd|fe[89ab])[0-9a-f:]+\]$/i.test(host);
  if (!local || !['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash ||
      !['', '/', '/api/v1/jobs', '/api/v1/status'].includes(url.pathname)) {
    throw new Error('Use the local address shown in MicroFantasy, for example http://192.168.1.20:8787.');
  }
  if (!url.port) url.port = '8787';
  url.pathname = '/';
  return url;
}

type LocalRequest = RequestInit & { targetAddressSpace: 'local' | 'loopback' };
export class MicroFantasyClient {
  // A bare window.fetch stored as an instance method receives the wrong `this`
  // in browsers. Keep the native call bound to its normal global context.
  constructor(private readonly base: URL, private readonly fetcher: typeof fetch = (input, init) => fetch(input, init)) {}

  private async request(path: string, init: RequestInit, signal?: AbortSignal) {
    const timeout = AbortSignal.timeout(12000);
    const combined = signal ? AbortSignal.any([signal, timeout]) : timeout;
    const loopback = ['localhost', '[::1]'].includes(this.base.hostname) || this.base.hostname.startsWith('127.') || this.base.hostname.endsWith('.localhost');
    const request: LocalRequest = { ...init, signal: combined, mode: 'cors', credentials: 'omit', cache: 'no-store',
      redirect: 'error', targetAddressSpace: loopback ? 'loopback' : 'local' };
    let response: Response;
    try { response = await this.fetcher(new URL(path, this.base), request); }
    catch (error) {
      if (signal?.aborted) throw error;
      console.warn('[MicroFantasy] Local receiver connection failed', error);
      throw new Error('Cannot reach MicroFantasy. Keep Receive over Wi-Fi enabled on the phone, use the same LAN, and allow local network access in your browser. If your browser blocks it, download the job JSON and import it in the app.');
    }
    const data = await response.json().catch(() => null);
    if (!response.ok) {
      if (response.status === 401) throw new Error('Update MicroFantasy on the phone to send without a pairing code.');
      if (response.status === 403) throw new Error('This receiver does not allow this page. Update MicroFantasy on the phone.');
      if (response.status === 413) throw new Error('This job exceeds the receiver limit. Use Download JSON and import it in MicroFantasy.');
      throw new Error(`MicroFantasy rejected the job (${response.status}): ${data?.error?.message ?? 'Please review the phone.'}`);
    }
    return data;
  }

  async check(signal?: AbortSignal): Promise<{ maxBytes: number }> {
    const data = await this.request('/api/v1/status', { method: 'GET' }, signal);
    if (data?.service !== 'microfantasy' || data.api_version !== 1 || data.accepting_jobs !== true) {
      throw new Error('The address does not identify an available MicroFantasy receiver.');
    }
    if (!Array.isArray(data.cut_helper_versions) || !data.cut_helper_versions.includes(1)) {
      throw new Error('Update MicroFantasy on the phone: this version cannot display the V90 Cut Helper.');
    }
    return { maxBytes: Number.isSafeInteger(data.max_job_bytes) && data.max_job_bytes > 0 ? data.max_job_bytes : 1048576 };
  }

  async send(job: MicroFantasyJob, signal?: AbortSignal) {
    const { maxBytes } = await this.check(signal);
    const body = JSON.stringify(job);
    if (new TextEncoder().encode(body).byteLength > maxBytes) throw new Error('This job is too large for LAN transfer. Download the JSON and import it in the app.');
    const data = await this.request('/api/v1/jobs', { method: 'POST',
      headers: { 'Content-Type': 'application/json' }, body }, signal);
    if (data?.status !== 'pending' || data.job_id !== job.jobId || data.cut_helper_version !== 1) {
      throw new Error('The receiver did not confirm this Cut Helper. Check the phone before trying again.');
    }
  }
}

/** No subnet sweep: probe the last address and the ESP32's live client list. */
export async function discoverMicroFantasy(previous: string, signal: AbortSignal,
  fetcher: typeof fetch = (input, init) => fetch(input, init)): Promise<string[]> {
  const candidates = new Set<string>();
  if (previous.trim()) {
    try { candidates.add(microFantasyBaseUrl(previous).origin); } catch { /* Ignore obsolete address. */ }
  }
  const init: LocalRequest = { signal: AbortSignal.any([signal, AbortSignal.timeout(3500)]),
    mode: 'cors', credentials: 'omit', cache: 'no-store', redirect: 'error', targetAddressSpace: 'local' };
  try {
    const response = await fetcher('http://fantasy-machine.local/api/v1/apps', init);
    const data = await response.json();
    if (response.ok && data?.service === 'microfantasy-machine' && data.api_version === 1 && Array.isArray(data.apps)) {
      for (const address of data.apps.slice(0, 5)) {
        if (typeof address !== 'string') continue;
        try { candidates.add(microFantasyBaseUrl(address).origin); } catch { /* Never probe external addresses. */ }
      }
    }
  } catch { /* ESP32 may be absent; the remembered address still works. */ }
  if (signal.aborted) return [];
  const checks = await Promise.allSettled([...candidates].map(async (address) => {
    await new MicroFantasyClient(microFantasyBaseUrl(address), fetcher).check(
      AbortSignal.any([signal, AbortSignal.timeout(3500)]));
    return address;
  }));
  return checks.flatMap((result) => result.status === 'fulfilled' ? [result.value] : []);
}
