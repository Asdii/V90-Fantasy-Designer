import { useEffect, useMemo, useRef, useState } from 'react';
import type { CutHelperStep, CutHelperView } from '../grooves/CutHelper';
import { createMicroFantasyJob } from '../integrations/MicroFantasyJob';
import { microFantasyBaseUrl, MicroFantasyClient } from '../integrations/MicroFantasyClient';

export function SendToMicroFantasyDialog({ steps, view, defaultName, onClose }: {
  steps: readonly CutHelperStep[]; view: CutHelperView; defaultName: string; onClose: () => void;
}) {
  const [address, setAddress] = useState(() => { try { return localStorage.getItem('microfantasy.address') ?? ''; } catch { return ''; } });
  const [token, setToken] = useState('');
  const [name, setName] = useState(defaultName);
  const [centerX, setCenterX] = useState('0');
  const [status, setStatus] = useState('');
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);
  const active = useRef<AbortController | null>(null);
  const [jobId] = useState(() => crypto.randomUUID());
  const count = useMemo(() => new Set(steps.map((s) => s.operationId)).size, [steps]);
  useEffect(() => () => active.current?.abort(), []);
  const job = () => createMicroFantasyJob(steps, { jobId, name, view, machineCenterXmm: Number(centerX.replace(',', '.')) });
  const connect = async (send: boolean) => {
    if (active.current) return;
    const controller = new AbortController(); active.current = controller;
    setBusy(true); setFailed(false); setStatus(send ? 'Sending Cut Helper…' : 'Looking for MicroFantasy…');
    try {
      const base = microFantasyBaseUrl(address);
      const client = new MicroFantasyClient(base);
      if (send) await client.send(job(), token, controller.signal); else await client.check(controller.signal);
      try { localStorage.setItem('microfantasy.address', base.origin); } catch { /* Address storage is optional. */ }
      setStatus(send ? 'Received by MicroFantasy. Tap Open on the phone to start.' : 'MicroFantasy is available and supports this Cut Helper.');
    } catch (error) {
      if (!controller.signal.aborted) { setFailed(true); setStatus(error instanceof Error ? error.message : String(error)); }
    } finally {
      if (!controller.signal.aborted) { setBusy(false); active.current = null; }
    }
  };
  const download = () => {
    try {
      const data = job();
      const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }));
      const link = document.createElement('a'); link.href = url; link.download = 'microfantasy-cut-helper.json'; link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setFailed(false); setStatus('JSON exported with the same Cut Helper. Import it in MicroFantasy.');
    } catch (error) { setFailed(true); setStatus(String(error)); }
  };
  return <div className="cutHelperBackdrop">
    <section className="mobileSendDialog" role="dialog" aria-modal="true" aria-labelledby="mobile-send-title">
      <header className="cutHelperHeader"><h2 id="mobile-send-title">Send to MicroFantasy</h2>
        <button className="toolbarButton" onClick={onClose}>Close</button></header>
      <div className="mobileSendBody">
        <p>{steps.length} cuts · {count} operations · Reference facet {steps[0].facetId}</p>
        <p>The created cuts shown in Cut Helper are sent in the same order, with their reference facet, wheel, distances and depths.</p>
        <label>Job name<input value={name} maxLength={120} onChange={(e) => setName(e.target.value)} disabled={busy} /></label>
        <label>X at the facet center (mm)<input type="number" step="0.001" value={centerX} onChange={(e) => setCenterX(e.target.value)} disabled={busy} /></label>
        <small>Use 0 if the X reading is zero at the reference center. Otherwise enter that reading. Calibration compensation is applied by MicroFantasy.</small>
        <ol><li>On the phone, open Configuration → V90 Fantasy Designer → Receive over Wi-Fi.</li>
          <li>Keep the app open on the same network. Copy its address and pairing code below.</li></ol>
        <label>Phone address<input placeholder="http://192.168.1.20:8787" value={address} onChange={(e) => setAddress(e.target.value)} disabled={busy} autoComplete="off" /></label>
        <label>Pairing code<input type="password" value={token} onChange={(e) => setToken(e.target.value.trim())} disabled={busy} autoComplete="off" /></label>
        <small>Your browser may ask for local network access. If it blocks LAN connections, the JSON file includes the complete same viewer.</small>
        <p role={failed ? 'alert' : 'status'} className={failed ? 'mobileSendError' : ''}>{status}</p>
        <div className="mobileSendActions">
          <button className="toolbarButton" disabled={busy || !address.trim()} onClick={() => void connect(false)}>Test connection</button>
          <button className="toolbarButton active" disabled={busy || !address.trim() || !token || !name.trim() || !centerX.trim()} onClick={() => void connect(true)}>{busy ? 'Please wait…' : 'Send Cut Helper'}</button>
          <button className="toolbarButton" disabled={busy} onClick={download}>Download JSON</button>
        </div>
      </div>
    </section>
  </div>;
}
