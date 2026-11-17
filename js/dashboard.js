(async () => {
  try {
    const d = await api('dashboard');
    document.getElementById('s-sales').textContent   = peso(d.sales);
    document.getElementById('s-orders').textContent  = d.orders;
    document.getElementById('s-pending').textContent = d.pending;
    document.getElementById('s-damaged').textContent = d.damaged;

    document.getElementById('tbody-recent').innerHTML = d.recent.length
      ? d.recent.map(r => `<tr><td>#${r.order_id}</td><td>${esc(r.customer)}</td><td>${peso(r.total_amount)}</td><td>${badge(r.status)}</td></tr>`).join('')
      : emptyRow(4, 'No orders yet');

    document.getElementById('tbody-alerts').innerHTML = d.alerts.length
      ? d.alerts.map(r => `<tr><td>${esc(r.label_mark || '#' + r.container_id)}</td><td>${esc(r.owner)}</td><td>${badge(r.current_condition)}</td></tr>`).join('')
      : emptyRow(3, 'All containers are in good condition');
  } catch (e) { toast(e.message, 'error'); }
})();