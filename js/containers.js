let L = {}, rows = [];
const fReg = document.getElementById('f-reg'), fCheck = document.getElementById('f-check'), fTxn = document.getElementById('f-txn');
const tbody = document.getElementById('tbody');
const CONDITIONS = ['Good', 'Dirty', 'Cracked', 'Worn Out'];

async function loadLookups() {
  L = await api('lookups');
  const label = c => `${c.label_mark || 'No label #' + c.container_id} — ${c.owner}`;
  fillSelect(fReg.customer_id, L.customers, c => c.customer_id, c => c.full_name);
  fillSelect(fCheck.container_id, L.containers, c => c.container_id, label);
  fillSelect(fCheck.order_id, L.orders, o => o.order_id, o => `#${o.order_id} — ${o.full_name}`);
  fillSelect(fTxn.container_id, L.containers, c => c.container_id, label);
}

async function submitForm(form, action, okMsg, extra) {
  const btn = form.querySelector('button[type=submit]');
  busy(btn, true);
  try {
    await api('containers', action, Object.fromEntries(new FormData(form)));
    toast(okMsg); form.reset(); await loadLookups(); load();
  } catch (err) { toast(err.message, 'error'); }
  finally { busy(btn, false); }
}

fReg.addEventListener('submit', e => { e.preventDefault(); submitForm(fReg, 'add', 'Container registered'); });

fCheck.addEventListener('submit', async e => {
  e.preventDefault();
  if (fCheck.condition_result.value === 'Damaged/Rejected') {
    const ok = await confirmBox({ title: 'Reject this container?',
      message: 'It will be flagged as Cracked and should not be refilled.', confirmText: 'Reject Container', danger: true });
    if (!ok) return;
  }
  submitForm(fCheck, 'check', 'Condition check recorded');
});

fTxn.addEventListener('submit', e => {
  e.preventDefault();
  submitForm(fTxn, 'txn', `${fTxn.txn_type.value} recorded`);
});

async function load() {
  try { rows = await api('containers'); } catch (e) { return toast(e.message, 'error'); }
  tbody.innerHTML = rows.length ? rows.map(r => `
    <tr><td>${r.container_id}</td><td>${esc(r.label_mark || '-')}</td><td>${esc(r.owner)}</td><td>${esc(r.size)}</td>
      <td>${badge(r.current_condition)}</td><td>${badge(r.return_status)}</td>
      <td><button class="icon-btn" data-edit="${r.container_id}" title="Change condition"><i class="fa-solid fa-pen"></i></button>
          <button class="icon-btn danger" data-del="${r.container_id}" title="Delete"><i class="fa-solid fa-trash"></i></button></td></tr>`).join('')
    : emptyRow(7, 'No containers registered yet.');
  applySearch();
}

tbody.addEventListener('click', async e => {
  const ed = e.target.closest('[data-edit]'), del = e.target.closest('[data-del]');
  if (ed) {
    const r = rows.find(x => x.container_id == ed.dataset.edit);
    modal({ title: `Container ${r.label_mark || '#' + r.container_id}`, submitText: 'Update',
      body: `<div class="field"><label>Condition</label><select name="current_condition">${CONDITIONS.map(c =>
        `<option ${c === r.current_condition ? 'selected' : ''}>${c}</option>`).join('')}</select></div>`,
      onSubmit: async d => { await api('containers', 'update', { container_id: r.container_id, ...d }); toast('Condition updated'); load(); } });
  }
  if (del) {
    const r = rows.find(x => x.container_id == del.dataset.del);
    if (!await confirmBox({ title: 'Delete container?', message: `${r.label_mark || '#' + r.container_id} (${r.owner}) will be removed.`, confirmText: 'Delete', danger: true })) return;
    try { await api('containers', 'delete', { container_id: r.container_id }); toast('Container deleted'); await loadLookups(); load(); }
    catch (err) { toast(err.message, 'error'); }
  }
});

(async () => { try { await loadLookups(); load(); } catch (e) { toast(e.message, 'error'); } })();