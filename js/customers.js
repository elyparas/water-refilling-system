let rows = [];
const form = document.getElementById('form');
const tbody = document.getElementById('tbody');

const fields = (r = {}) => `
  <div class="field"><label>Full Name</label><input name="full_name" required value="${esc(r.full_name)}"></div>
  <div class="field"><label>Contact No.</label><input name="contact_no" required pattern="(09|[+]639)[0-9 ]{9,12}" title="Example: 09171234567" value="${esc(r.contact_no)}"></div>
  <div class="field"><label>Address</label><textarea name="address" rows="2" required>${esc(r.address)}</textarea></div>`;

async function load() {
  try { rows = await api('customers'); } catch (e) { return toast(e.message, 'error'); }
  tbody.innerHTML = rows.length ? rows.map(r => `
    <tr><td>${r.customer_id}</td><td>${esc(r.full_name)}</td><td>${esc(r.contact_no)}</td><td>${esc(r.address)}</td>
      <td><button class="icon-btn" data-edit="${r.customer_id}" title="Edit"><i class="fa-solid fa-pen"></i></button>
          <button class="icon-btn danger" data-del="${r.customer_id}" title="Delete"><i class="fa-solid fa-trash"></i></button></td></tr>`).join('')
    : emptyRow(5, 'No customers yet. Register your first customer above.');
  applySearch();
}

form.addEventListener('submit', async e => {
  e.preventDefault();
  const btn = form.querySelector('button[type=submit]');
  busy(btn, true);
  try {
    await api('customers', 'add', Object.fromEntries(new FormData(form)));
    toast('Customer added successfully');
    form.reset(); load();
  } catch (err) { toast(err.message, 'error'); }
  finally { busy(btn, false); }
});

tbody.addEventListener('click', async e => {
  const ed = e.target.closest('[data-edit]'), del = e.target.closest('[data-del]');
  if (ed) {
    const r = rows.find(x => x.customer_id == ed.dataset.edit);
    modal({ title: 'Edit Customer', body: fields(r), submitText: 'Save Changes',
      onSubmit: async d => { await api('customers', 'update', { ...d, customer_id: r.customer_id }); toast('Customer updated'); load(); } });
  }
  if (del) {
    const r = rows.find(x => x.customer_id == del.dataset.del);
    const ok = await confirmBox({ title: 'Delete customer?', message: `${r.full_name} will be permanently removed.`, confirmText: 'Delete', danger: true });
    if (!ok) return;
    try { await api('customers', 'delete', { customer_id: r.customer_id }); toast('Customer deleted'); load(); }
    catch (err) { toast(err.message, 'error'); }
  }
});

load();