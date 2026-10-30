import { useEffect, useMemo, useRef, useState } from 'react';
import type { CutHelperStep, CutHelperView } from '../grooves/CutHelper';
import { createMicroFantasyJob } from '../integrations/MicroFantasyJob';
import { discoverMicroFantasy, microFantasyBaseUrl, MicroFantasyClient } from '../integrations/MicroFantasyClient';

export function SendToMicroFantasyDialog({ steps, view, defaultName, onClose }: {
  steps: readonly CutHelperStep[]; view: CutHelperView; defaultName: string; onClose: () => void;
}) {
  const [address, setAddress] = useState(() => { try { return localStorage.getItem('microfantasy.address') ?? ''; } catch { return ''; } });
  const [phones, setPhones] = useState<string[]>([]);
  const [name, setName] = useState(defaultName);
  const [centerX, setCenterX] = useState('0');
  const [status, setStatus] = useState('');
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);
  const active = useRef<AbortController | null>(null);
  const [jobId] = useState(() => crypto.randomUUID());
  const count = useMemo(() => new Set(steps.map((s) => s.operationId)).size, [steps]);
  useEffect(() => {
    void findPhone();
    return () => { active.current?.abort(); active.current = null; };
  }, []);
  async function findPhone() {
    if (active.current) return;
    const controller = new AbortController(); active.current = controller;
    setBusy(true); setFailed(false); setStatus('Looking for MicroFantasy…');
    try {
      const found = await discoverMicroFantasy(address, controller.signal);
      if (controller.signal.aborted) return;
      setPhones(found);
      if (found.length === 1) setAddress(found[0]);
      setStatus(found.length ? 'Phone found. Select its address and send the Cut Helper.' :
        'No phone found automatically. Keep MicroFantasy receiving over Wi-Fi and connected to the ESP32, or enter the phone IP below.');
    } finally {
      if (!controller.signal.aborted) { setBusy(false); active.current = null; }
    }
  }
  const job = () => createMicroFantasyJob(steps, { jobId, name, view, machineCenterXmm: Number(centerX.replace(',', '.')) });
  const connect = async (send: boolean) => {
    if (active.current) return;
    const controller = new AbortController(); active.current = controller;
    setBusy(true); setFailed(false); setStatus(send ? 'Sending Cut Helper…' : 'Looking for MicroFantasy…');
    try {
      const base = microFantasyBaseUrl(address);
      const client = new MicroFantasyClient(base);
      if (send) await client.send(job(), controller.signal); else await client.check(controller.signal);
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
          <li>Keep the app open on the same network. No pairing code is needed.</li></ol>
        {phones.length > 1 && <label>Phones found<select value={address} onChange={(e) => setAddress(e.target.value)}>
          <option value="">Choose phone</option>{phones.map((phone) => <option key={phone} value={phone}>{phone}</option>)}</select></label>}
        <label>Phone address<input placeholder="http://192.168.1.20:8787" value={address} onChange={(e) => setAddress(e.target.value)} disabled={busy} autoComplete="off" /></label>
        <small>Your browser may ask for local network access. If it blocks LAN connections, the JSON file includes the complete same viewer.</small>
        <p role={failed ? 'alert' : 'status'} className={failed ? 'mobileSendError' : ''}>{status}</p>
        <div className="mobileSendActions">
          <button className="toolbarButton" disabled={busy} onClick={() => void findPhone()}>Find phone</button>
          <button className="toolbarButton" disabled={busy || !address.trim()} onClick={() => void connect(false)}>Test connection</button>
          <button className="toolbarButton active" disabled={busy || !address.trim() || !name.trim() || !centerX.trim()} onClick={() => void connect(true)}>{busy ? 'Please wait…' : 'Send Cut Helper'}</button>
          <button className="toolbarButton" disabled={busy} onClick={download}>Download JSON</button>
        </div>
      </div>
    </section>
  </div>;
}
