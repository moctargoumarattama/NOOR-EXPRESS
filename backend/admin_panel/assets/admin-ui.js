const AdminUI = (() => {
  const navItems = [
    { key: 'dashboard', label: 'Tableau de bord', href: 'dashboard.html' },
    { key: 'rides', label: 'Courses', href: 'rides.html' },
    { key: 'users', label: 'Utilisateurs', href: 'users.html' },
    { key: 'drivers', label: 'Chauffeurs à valider', href: 'drivers.html' },
    { key: 'pricing', label: 'Zones & tarifs', href: 'zones.html' },
    { key: 'payments', label: 'Paiements', href: 'payments.html' },
    { key: 'reports', label: 'Signalements', href: 'reports.html' },
    { key: 'notifications', label: 'Notifications', href: 'notifications.html' },
    { key: 'simulations', label: 'Simulations DEV', href: 'simulations.html', devOnly: true },
    { key: 'settings', label: 'Paramètres', href: 'settings.html' },
  ];

  function escapeHtml(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }

  function initShell(activeKey) {
    applyStoredTheme();
    const sidebar = document.querySelector('[data-admin-sidebar]');
    if (!sidebar) return;
    const active = activeKey || document.body.dataset.activePage || '';
    sidebar.innerHTML = `
      <div class="brand-block">
        <div class="logo-mark" aria-hidden="true">N</div>
        <div>
          <strong>Noor Express</strong>
          <span>Opérations admin</span>
        </div>
      </div>
      <nav class="admin-nav">
        ${navItems.map((item) => `
          <a class="${item.key === active ? 'active' : ''}" href="${item.href}" ${item.devOnly ? 'data-dev-only="true"' : ''}>
            <span>${escapeHtml(item.label)}</span>
          </a>
        `).join('')}
      </nav>
      <button class="theme-toggle" onclick="AdminUI.toggleTheme()" type="button">Mode sombre</button>
      <button class="logout-button" onclick="AdminApi.logout()">Déconnexion</button>
    `;
    updateThemeButton();
    updateDevNavigation();
  }

  function applyStoredTheme() {
    const theme = localStorage.getItem('noor_admin_theme') || 'light';
    document.documentElement.dataset.theme = theme;
  }

  function toggleTheme() {
    const current = document.documentElement.dataset.theme || 'light';
    const next = current === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    localStorage.setItem('noor_admin_theme', next);
    updateThemeButton();
  }

  function updateThemeButton() {
    const button = document.querySelector('.theme-toggle');
    if (!button) return;
    button.textContent = (document.documentElement.dataset.theme || 'light') === 'dark'
      ? 'Mode clair'
      : 'Mode sombre';
  }

  async function updateDevNavigation() {
    const devLink = document.querySelector('[data-dev-only="true"]');
    if (!devLink) return;
    const token = localStorage.getItem('noor_admin_token');
    if (!token) return;
    try {
      const response = await fetch(`${window.location.origin}/admin/simulations/status`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!response.ok) devLink.remove();
    } catch (_error) {
      devLink.remove();
    }
  }

  function statCard(label, value, hint = '') {
    return `<article class="metric-card"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong>${hint ? `<small>${escapeHtml(hint)}</small>` : ''}</article>`;
  }

  function emptyState(message, colspan = 1) {
    return `<tr><td colspan="${colspan}" class="empty-state">${escapeHtml(message)}</td></tr>`;
  }

  function badge(value, tone = 'neutral') {
    return `<span class="badge ${tone}">${escapeHtml(value)}</span>`;
  }

  function money(value) {
    const number = Number(value || 0);
    return `${Math.round(number).toLocaleString('fr-FR')} FCFA`;
  }

  return { initShell, toggleTheme, statCard, emptyState, badge, money, escapeHtml };
})();

document.addEventListener('DOMContentLoaded', () => AdminUI.initShell());

