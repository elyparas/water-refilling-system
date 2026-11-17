const API = 'api/';

/* ---------- helpers ---------- */
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
const peso = n => '₱' + Number(n || 0).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const dt = s => s ? new Date(String(s).replace(' ', 'T')).toLocaleString('en-PH', { dateStyle: 'medium', timeStyle: 'short' }) : '-';
const emptyRow = (cols, msg) => `<tr><td colspan="${cols}" class="empty">${msg}</td></tr>`;

const tones = {
  'Completed':'green','Delivered':'green','Good':'green','Returned':'green','Clean/Approved':'green','Fully Paid':'green',
  'Pending':'amber','Refilling':'amber','Pending Return':'amber','Dirty':'amber','Needs Sanitization':'amber','Unpaid':'amber',
  'Ready for Pickup':'blue','Out for Delivery':'blue',
  'Cancelled':'red','Failed':'red','Cracked':'red','Worn Out':'red','Lost':'red','Damaged/Rejected':'red'
};
const badge = s => s ? `<span class="badge ${tones[s] || 'gray'}">${esc(s)}</span>` : '<span class="muted">-</span>';

function fillSelect(sel, items, val, label, placeholder) {
  sel.innerHTML = (placeholder ? `<option value="">${placeholder}</option>` : '') +
    items.map(i => `<option value="${esc(val(i))}">${esc(label(i))}</option>`).join('');
}

/* ---------- API ---------- */
async function api(file, action = 'list', body = null, params = '') {
  let res;
  try {
    res = await fetch(`${API}${file}.php?action=${action}${params}`,
      body ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) } : {});
  } catch {
    throw new Error('Cannot reach the server. Open the app through Apache (e.g. http://localhost/water-refilling-system/), not by double-clicking the file, and make sure Apache and MySQL are running in XAMPP.');
  }
  const text = await res.text();
  let data;
  try { data = JSON.parse(text); }
  catch {
    throw new Error('The server did not return data. PHP is not running for this page - open the app via http://localhost/... from the XAMPP htdocs folder (not Live Server or file://), and start Apache and MySQL.');
  }
  if (!res.ok || (data && !Array.isArray(data) && data.error)) throw new Error(data.error || 'Something went wrong.');
  return data;
}

/* ---------- toast ---------- */
function toast(msg, type = 'success') {
  let box = document.getElementById('toasts');
  if (!box) { box = document.createElement('div'); box.id = 'toasts'; document.body.appendChild(box); }
  const icons = { success: 'fa-circle-check', error: 'fa-circle-xmark', info: 'fa-circle-info' };
  const t = document.createElement('div');
  t.className = 'toast ' + type;
  t.innerHTML = `<i class="fa-solid ${icons[type]}"></i><span>${esc(msg)}</span>`;
  box.appendChild(t);
  setTimeout(() => { t.classList.add('hide'); setTimeout(() => t.remove(), 300); }, 3500);
}

/* ---------- button loading state ---------- */
function busy(btn, on) {
  if (!btn) return;
  if (on) { btn._h = btn.innerHTML; btn.disabled = true; btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Please wait'; }
  else { btn.disabled = false; if (btn._h) btn.innerHTML = btn._h; }
}

/* ---------- confirm dialog (returns Promise<boolean>) ---------- */
function confirmBox({ title = 'Are you sure?', message = '', confirmText = 'Confirm', cancelText = 'Cancel', danger = false }) {
  return new Promise(resolve => {
    const wrap = document.createElement('div');
    wrap.className = 'overlay';
    wrap.innerHTML = `
      <div class="modal small center">
        <div class="confirm-icon ${danger ? 'danger' : ''}"><i class="fa-solid ${danger ? 'fa-triangle-exclamation' : 'fa-circle-question'}"></i></div>
        <h3>${esc(title)}</h3>
        <p class="muted">${esc(message)}</p>
        <div class="modal-foot center">
          <button class="btn ghost" data-close>${esc(cancelText)}</button>
          <button class="btn ${danger ? 'danger' : ''}" data-ok>${esc(confirmText)}</button>
        </div>
      </div>`;
    document.body.appendChild(wrap);
    const done = v => { wrap.remove(); resolve(v); };
    wrap.addEventListener('click', e => {
      if (e.target === wrap || e.target.closest('[data-close]')) done(false);
      else if (e.target.closest('[data-ok]')) done(true);
    });
    wrap.querySelector('[data-ok]').focus();
  });
}

/* ---------- form modal ---------- */
function modal({ title, body, submitText = 'Save', onSubmit = null, wide = false }) {
  const wrap = document.createElement('div');
  wrap.className = 'overlay';
  wrap.innerHTML = `
    <div class="modal ${wide ? 'wide' : ''}">
      <div class="modal-head"><h3>${esc(title)}</h3>
        <button type="button" class="icon-btn" data-close><i class="fa-solid fa-xmark"></i></button></div>
      <form class="modal-body">${body}
        <div class="modal-foot">
          <button type="button" class="btn ghost" data-close>${onSubmit ? 'Cancel' : 'Close'}</button>
          ${onSubmit ? `<button class="btn" type="submit">${esc(submitText)}</button>` : ''}
        </div>
      </form>
    </div>`;
  document.body.appendChild(wrap);
  const close = () => wrap.remove();
  wrap.addEventListener('click', e => { if (e.target === wrap || e.target.closest('[data-close]')) close(); });
  wrap.querySelector('form').addEventListener('submit', async e => {
    e.preventDefault();
    if (!onSubmit) return;
    const btn = wrap.querySelector('button[type=submit]');
    busy(btn, true);
    try { await onSubmit(Object.fromEntries(new FormData(e.target))); close(); }
    catch (err) { toast(err.message, 'error'); busy(btn, false); }
  });
  const first = wrap.querySelector('input, select, textarea');
  if (first) first.focus();
  return { el: wrap, close };
}

/* ---------- live search (any table with class "searchable") ---------- */
function applySearch() {
  const q = (document.getElementById('search')?.value || '').toLowerCase();
  document.querySelectorAll('table.searchable tbody tr').forEach(tr => {
    tr.style.display = tr.textContent.toLowerCase().includes(q) ? '' : 'none';
  });
}
document.addEventListener('input', e => { if (e.target.id === 'search') applySearch(); });

/* ---------- Esc closes the top dialog ---------- */
document.addEventListener('keydown', e => {
  if (e.key !== 'Escape') return;
  const o = [...document.querySelectorAll('.overlay')].pop();
  if (o) o.querySelector('[data-close]')?.click();
});