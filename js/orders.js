const STATUSES = ['Pending', 'Refilling', 'Ready for Pickup', 'Out for Delivery', 'Completed'];
let L = {}, rows = [];
const form = document.getElementById('form');
const itemsBox = document.getElementById('items');
const totalEl = document.getElementById('total');
const tbody = document.getElementById('tbody');

function itemRow() {
  const d = document.createElement('div');
  d.className = 'item-row';
  d.innerHTML = `
    <div class="field"><select required>${L.products.map(p =>
      `<option value="${p.product_id}" data-price="${p.unit_price}">${esc(p.product_name)} — ${peso(p.unit_price)}</option>`).join('')}</select></div>
    <div class="field"><input type="number" min="1" value="1" required></div>
    <button type="button" class="icon-btn danger" data-rm title="Remove"><i class="fa-solid fa-xmark"></i></button>`;
  itemsBox.appendChild(d);
}

function recalc() {
  let t = 0;
  itemsBox.querySelectorAll('.item-row').forEach(r => {
    const price = Number(r.querySelector('select').selectedOptions[0].dataset.price);
    t += price * Number(r.querySelector('input').value || 0);
  });
  t += Number(form.delivery_fee.value || 0) + Number(form.container_deposit.value || 0);
  totalEl.textContent = peso(t);
  return t;
}

document.getElementById('addItem').addEventListener('click', () => { itemRow(); recalc(); });
itemsBox.addEventListener('click', e => {
  if (!e.target.closest('[data-rm]')) return;
  if (itemsBox.children.length === 1) return toast('An order needs at least one item', 'error');
  e.target.closest('.item-row').remove(); recalc();
});
form.addEventListener('input', recalc);
form.addEventListener('change', recalc);

form.addEventListener('submit', async e => {
  e.preventDefault();
  const list = [...itemsBox.querySelectorAll('.item-row')].map(r => ({
    product_id: r.querySelector('select').value, quantity: Number(r.querySelector('input').value) }));
  const total = recalc();
  const ok = await confirmBox({ title: 'Create this order?',
    message: `${form.customer_id.selectedOptions[0].text} • ${list.length} item(s) • Total ${peso(total)}`, confirmText: 'Create Order' });
  if (!ok) return;
  const btn = form.querySelector('button[type=submit]');
  busy(btn, true);
  try {
    const r = await api('orders', 'add', {
      customer_id: form.customer_id.value, staff_id: form.staff_id.value, status: form.status.value,
      delivery_fee: form.delivery_fee.value || 0, container_deposit: form.container_deposit.value || 0, items: list });
    toast(`Order #${r.order_id} created`);
    form.reset(); itemsBox.innerHTML = ''; itemRow(); recalc(); load();
  } catch (err) { toast(err.message, 'error'); }
  finally { busy(btn, false); }
});

async function load() {
  try { rows = await api('orders'); } catch (e) { return toast(e.message, 'error'); }
  tbody.innerHTML = rows.length ? rows.map(r => {
    const closed = ['Completed', 'Cancelled'].includes(r.status);
    return `<tr><td>#${r.order_id}</td><td>${esc(r.customer)}</td><td>${dt(r.order_date)}</td>
      <td>${peso(r.total_amount)}</td><td>${peso(r.balance)}</td><td>${badge(r.status)}</td>
      <td><button class="icon-btn" data-view="${r.order_id}" title="View"><i class="fa-solid fa-eye"></i></button>
      ${closed ? '' : `<button class="icon-btn" data-status="${r.order_id}" title="Update status"><i class="fa-solid fa-arrows-rotate"></i></button>
      <button class="icon-btn danger" data-cancel="${r.order_id}" title="Cancel order"><i class="fa-solid fa-ban"></i></button>`}</td></tr>`;
  }).join('') : emptyRow(7, 'No orders yet. Create your first order above.');
  applySearch();
}

tbody.addEventListener('click', async e => {
  const v = e.target.closest('[data-view]'), s = e.target.closest('[data-status]'), c = e.target.closest('[data-cancel]');

  if (v) {
    try {
      const d = await api('orders', 'view', null, `&id=${v.dataset.view}`);
      const o = d.order, paid = d.payments.reduce((a, p) => a + Number(p.amount), 0);
      modal({ title: `Order #${o.order_id}`, wide: true, body: `
        <p class="muted">${esc(o.customer)} • ${dt(o.order_date)} • Staff: ${esc(o.staff)} • ${badge(o.status)}</p>
        <table style="margin-top:12px"><thead><tr><th>Item</th><th>Qty</th><th>Price</th><th>Subtotal</th></tr></thead><tbody>
          ${d.items.map(i => `<tr><td>${esc(i.product_name)}</td><td>${i.quantity}</td><td>${peso(i.unit_price)}</td><td>${peso(i.quantity * i.unit_price)}</td></tr>`).join('')}
        </tbody></table>
        <div class="sum">
          <div><span>Delivery fee</span><b>${peso(o.delivery_fee)}</b></div>
          <div><span>Container deposit</span><b>${peso(o.container_deposit)}</b></div>
          <div><span>Total</span><b>${peso(o.total_amount)}</b></div>
          <div><span>Paid</span><b>${peso(paid)}</b></div>
          <div><span>Balance</span><b>${peso(o.total_amount - paid)}</b></div>
        </div>` });
    } catch (err) { toast(err.message, 'error'); }
  }

  if (s) {
    const id = s.dataset.status, r = rows.find(x => x.order_id == id);
    modal({ title: `Update Order #${id}`, submitText: 'Update',
      body: `<div class="field"><label>Status</label><select name="status">${STATUSES.map(x =>
        `<option ${x === r.status ? 'selected' : ''}>${x}</option>`).join('')}</select></div>`,
      onSubmit: async d => { await api('orders', 'status', { order_id: id, status: d.status }); toast(`Order #${id} is now ${d.status}`); load(); } });
  }

  if (c) {
    const id = c.dataset.cancel;
    const ok = await confirmBox({ title: `Cancel order #${id}?`, message: 'The order will be marked as Cancelled and cannot be reopened.',
      confirmText: 'Yes, cancel order', cancelText: 'Keep order', danger: true });
    if (!ok) return;
    try { await api('orders', 'status', { order_id: id, status: 'Cancelled' }); toast(`Order #${id} cancelled`); load(); }
    catch (err) { toast(err.message, 'error'); }
  }
});

(async () => {
  try {
    L = await api('lookups');
    fillSelect(form.customer_id, L.customers, c => c.customer_id, c => c.full_name);
    fillSelect(form.staff_id, L.staff, s => s.staff_id, s => `${s.full_name} (${s.role})`);
    itemRow(); recalc(); load();
  } catch (e) { toast(e.message, 'error'); }
})();