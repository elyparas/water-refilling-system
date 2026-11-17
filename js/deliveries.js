let L = {}, rows = [];
const form = document.getElementById('form');
const tbody = document.getElementById('tbody');

const setNow = () => { form.delivery_date.value = new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 16); };

async function loadLookups() {
  L = await api('lookups');
  const open = L.orders.filter(o => !['Completed', 'Cancelled'].includes(o.status));
  fillSelect(form.order_id, open, o => o.order_id, o => `#${o.order_id} — ${o.full_name}`, 'Select order');
  fillSelect(form.staff_id, L.staff, s => s.staff_id, s => `${s.full_name} (${s.role})`);
}

form.order_id.addEventListener('change', () => {
  const o = L.orders.find(x => x.order_id == form.order_id.value);
  if (o) form.delivery_address.value = o.address;
});

form.addEventListener('submit', async e => {
  e.preventDefault();
  const btn = form.querySelector('button[type=submit]');
  busy(btn, true);
  try {
    await api('deliveries', 'add', Object.fromEntries(new FormData(form)));
    toast('Delivery scheduled');
    form.reset(); setNow(); await loadLookups(); load();
  } catch (err) { toast(err.message, 'error'); }
  finally { busy(btn, false); }
});

async function load() {
  try { rows = await api('deliveries'); } catch (e) { return toast(e.message, 'error'); }
  tbody.innerHTML = rows.length ? rows.map(r => `
    <tr><td>${r.delivery_id}</td><td>#${r.order_id}</td><td>${esc(r.customer)}</td><td>${esc(r.rider)}</td>
      <td>${esc(r.delivery_address)}</td><td>${dt(r.delivery_date)}</td><td>${badge(r.delivery_status)}</td>
      <td>${r.delivery_status === 'Out for Delivery' ? `
        <button class="icon-btn" data-done="${r.delivery_id}" title="Mark delivered"><i class="fa-solid fa-circle-check"></i></button>
        <button class="icon-btn danger" data-fail="${r.delivery_id}" title="Mark failed"><i class="fa-solid fa-circle-xmark"></i></button>` : ''}
        <button class="icon-btn danger" data-del="${r.delivery_id}" title="Delete"><i class="fa-solid fa-trash"></i></button></td></tr>`).join('')
    : emptyRow(8, 'No deliveries scheduled yet.');
  applySearch();
}

async function setStatus(id, status, msg) {
  try { await api('deliveries', 'status', { delivery_id: id, status }); toast(msg); await loadLookups(); load(); }
  catch (err) { toast(err.message, 'error'); }
}

tbody.addEventListener('click', async e => {
  const done = e.target.closest('[data-done]'), fail = e.target.closest('[data-fail]'), del = e.target.closest('[data-del]');
  if (done) {
    const r = rows.find(x => x.delivery_id == done.dataset.done);
    if (await confirmBox({ title: 'Mark as delivered?', message: `Order #${r.order_id} will be marked Completed.`, confirmText: 'Mark Delivered' }))
      setStatus(r.delivery_id, 'Delivered', `Order #${r.order_id} delivered`);
  }
  if (fail) {
    const r = rows.find(x => x.delivery_id == fail.dataset.fail);
    if (await confirmBox({ title: 'Mark as failed?', message: `The delivery for order #${r.order_id} will be marked Failed.`, confirmText: 'Mark Failed', danger: true }))
      setStatus(r.delivery_id, 'Failed', 'Delivery marked as failed');
  }
  if (del) {
    const r = rows.find(x => x.delivery_id == del.dataset.del);
    if (await confirmBox({ title: 'Delete delivery record?', message: `Delivery #${r.delivery_id} will be permanently removed.`, confirmText: 'Delete', danger: true })) {
      try { await api('deliveries', 'delete', { delivery_id: r.delivery_id }); toast('Delivery deleted'); load(); }
      catch (err) { toast(err.message, 'error'); }
    }
  }
});

(async () => { try { await loadLookups(); setNow(); load(); } catch (e) { toast(e.message, 'error'); } })();