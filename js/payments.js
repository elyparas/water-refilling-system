let rows = [], open = [];
const form = document.getElementById('form');
const tbody = document.getElementById('tbody');
const hint = document.getElementById('hint');

async function loadOpen() {
  open = await api('payments', 'open');
  fillSelect(form.order_id, open, o => o.order_id, o => `#${o.order_id} — ${o.customer}`, 'Select order');
  hint.textContent = open.length ? '' : 'No orders with an unpaid balance.';
}

form.order_id.addEventListener('change', () => {
  const o = open.find(x => x.order_id == form.order_id.value);
  hint.textContent = o ? `Remaining balance: ${peso(o.balance)}` : '';
  if (o) form.amount.value = Number(o.balance).toFixed(2);
});

async function load() {
  const d = await api('payments');
  rows = d.rows;
  document.getElementById('st-collected').textContent = peso(d.stats.collected);
  document.getElementById('st-unpaid').textContent = peso(d.stats.unpaid);
  tbody.innerHTML = rows.length
    ? rows.map(r => `<tr><td>${r.payment_id}</td><td>#${r.order_id}</td><td>${esc(r.customer)}</td><td>${peso(r.amount)}</td>
        <td>${esc(r.method)}</td><td>${dt(r.payment_date)}</td><td>${badge(r.payment_status)}</td></tr>`).join('')
    : emptyRow(7, 'No payments recorded yet.');
  applySearch();
}

form.addEventListener('submit', async e => {
  e.preventDefault();
  const btn = form.querySelector('button[type=submit]');
  busy(btn, true);
  try {
    await api('payments', 'add', Object.fromEntries(new FormData(form)));
    toast('Payment saved');
    form.reset(); await loadOpen(); await load();
  } catch (err) { toast(err.message, 'error'); }
  finally { busy(btn, false); }
});

(async () => { try { await loadOpen(); await load(); } catch (e) { toast(e.message, 'error'); } })();
