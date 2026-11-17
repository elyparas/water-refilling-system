const pages = [
  ['index',      'Dashboard',  'fa-chart-pie'],
  ['customers',  'Customers',  'fa-users'],
  ['orders',     'Orders',     'fa-cart-shopping'],
  ['deliveries', 'Deliveries', 'fa-truck-fast'],
  ['containers', 'Containers', 'fa-bottle-water'],
  ['payments',   'Payments',   'fa-credit-card']
];

const current = document.body.dataset.page;

document.getElementById('sidebar').innerHTML = `
  <div class="brand"><i class="fa-solid fa-droplet"></i><span>AquaTrack</span></div>
  <nav>
    ${pages.map(p => `
      <a href="${p[0]}.html" class="${p[0] === current ? 'active' : ''}">
        <i class="fa-solid ${p[2]}"></i><span>${p[1]}</span>
      </a>`).join('')}
  </nav>`;