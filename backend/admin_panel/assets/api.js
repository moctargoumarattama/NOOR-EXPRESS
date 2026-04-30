const AdminApi = (() => {
  const API_BASE = window.location.origin;
  let zonesCache = [];
  let faresCache = [];
  let timeRulesCache = [];
  let ridesCache = [];
  let reportsCache = [];
  let usersCache = [];
  let pendingDriversCache = [];
  let simulationsDisabled = false;
  let simulationStatusTimer = null;
  let ridesPage = 1;
  const ridesPageSize = 12;
  let usersRoleFilter = 'client';

  const token = () => localStorage.getItem('noor_admin_token');
  const $ = (id) => document.getElementById(id);
  const setMessage = (text) => { if ($('message')) $('message').textContent = text; };
  const setText = (id, text) => { if ($(id)) $(id).textContent = text; };
  const escapeHtml = (value) => String(value || '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
  const isLoginPage = () => window.location.pathname.endsWith('/index.html') ||
    window.location.pathname.endsWith('/admin-panel/') ||
    window.location.pathname.endsWith('/admin-panel');

  function redirectToLogin(message = 'Session admin expiree. Reconnecte-toi.') {
    localStorage.removeItem('noor_admin_token');
    sessionStorage.setItem('noor_admin_message', message);
    if (isLoginPage()) return setMessage(message);
    window.location.href = 'index.html';
  }

  async function request(path, options = {}) {
    const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
    if (token()) headers.Authorization = `Bearer ${token()}`;
    const response = await fetch(`${API_BASE}${path}`, { ...options, headers });
    if (!response.ok) {
      const payload = await response.json().catch(() => ({}));
      const message = payload.message || payload.detail || 'Erreur API';
      const isAdminLogin = path === '/admin/auth/login' || path === '/admin/init';
      if (response.status === 401 && path.startsWith('/admin/') && !isAdminLogin) {
        redirectToLogin(message || 'Session admin expiree. Reconnecte-toi.');
      }
      throw new Error(message);
    }
    return response.status === 204 ? null : response.json();
  }

  function requireAuth() {
    if (!token()) redirectToLogin('Connecte-toi en admin pour voir cette page.');
  }

  function showLoginMessage() {
    const message = sessionStorage.getItem('noor_admin_message');
    if (!message) return;
    sessionStorage.removeItem('noor_admin_message');
    setMessage(message);
  }

  async function login(username, password) {
    try {
      const payload = await request('/admin/auth/login', {
        method: 'POST',
        body: JSON.stringify({ username, password }),
      });
      localStorage.setItem('noor_admin_token', payload.access_token);
      window.location.href = 'dashboard.html';
    } catch (error) { setMessage(error.message); }
  }

  async function initAdmin(username, password) {
    try {
      const payload = await request('/admin/init', {
        method: 'POST',
        body: JSON.stringify({ username, password }),
      });
      localStorage.setItem('noor_admin_token', payload.access_token);
      window.location.href = 'dashboard.html';
    } catch (error) { setMessage(error.message); }
  }

  function logout() {
    localStorage.removeItem('noor_admin_token');
    window.location.href = 'index.html';
  }

  const ui = () => window.AdminUI || {
    statCard: (label, value, hint = '') => `<article class="metric-card"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong><small>${escapeHtml(hint)}</small></article>`,
    emptyState: (message, colspan) => `<tr><td colspan="${colspan}" class="empty-state">${escapeHtml(message)}</td></tr>`,
    badge: (value) => `<span class="badge">${escapeHtml(value)}</span>`,
    money: (value) => `${Math.round(Number(value || 0))} FCFA`,
    escapeHtml,
  };

  const priceOf = (ride) => Number(ride.final_price || ride.agreed_price || ride.estimated_price || 0);
  const isToday = (value) => value && new Date(value).toDateString() === new Date().toDateString();
  const statusTone = (status) => {
    if (['cancelled', 'rejected', 'blocked'].includes(status)) return 'danger';
    if (['pending', 'offered', 'started', 'accepted', 'ouvert'].includes(status)) return 'warning';
    return 'neutral';
  };
  const archiveYear = () => document.querySelector('[data-archive-year]')?.value || '';
  const archiveMonth = () => document.querySelector('[data-archive-month]')?.value || '';
  function applyArchiveFilters(rows, dateKey = 'created_at') {
    const year = archiveYear();
    const month = archiveMonth();
    return rows.filter((row) => {
      const rawDate = row[dateKey] || row.submitted_at || row.created_at;
      if (!rawDate) return !year && !month;
      const date = new Date(rawDate);
      if (year && String(date.getFullYear()) !== year) return false;
      if (month && String(date.getMonth() + 1).padStart(2, '0') !== month) return false;
      return true;
    });
  }

  async function loadDashboard() {
    await loadOperationsDashboard();
  }

  async function loadOperationsDashboard() {
    const data = await request('/admin/dashboard');
    const [rides, users, drivers] = await Promise.all([
      request('/admin/rides').catch(() => []),
      request('/admin/users').catch(() => []),
      request('/admin/drivers').catch(() => []),
    ]);
    const todayRides = rides.filter((ride) => isToday(ride.created_at));
    const activeRides = rides.filter((ride) => ['accepted', 'arrived', 'started'].includes(ride.status));
    const onlineDrivers = drivers.filter((driver) => !driver.is_blocked && ['online', 'busy'].includes(driver.driver_status || ''));
    const activeClients = users.filter((user) => user.role === 'client' && !user.is_blocked);
    const cancelled = rides.filter((ride) => ride.status === 'cancelled').length;
    const cancelRate = rides.length ? `${Math.round((cancelled / rides.length) * 100)}%` : '0%';

    setText('metric-rides-today', todayRides.length);
    setText('metric-active-rides', activeRides.length || (data.accepted + data.started));
    setText('metric-online-drivers', onlineDrivers.length);
    setText('metric-active-clients', activeClients.length);
    setText('metric-revenue', ui().money(data.revenue));
    setText('metric-cancel-rate', cancelRate);

    const stats = [
      ['Total courses', data.total_rides],
      ['En cours', data.accepted + data.started],
      ['Completees', data.completed],
      ['Annulees', data.cancelled],
      ['Revenus', `${Math.round(data.revenue)} FCFA`],
      ['Users', data.total_users],
    ];
    if ($('stats')) $('stats').innerHTML = stats.map(([label, value]) => ui().statCard(label, value)).join('');
    if ($('top-drivers')) $('top-drivers').innerHTML = (data.top_drivers || []).length
      ? data.top_drivers.map((driver) => `<tr><td>${escapeHtml(driver.phone_number)}</td><td>${driver.completed_rides}</td><td>${ui().money(driver.total_earnings)}</td></tr>`).join('')
      : ui().emptyState('Aucun chauffeur dans le classement.', 3);
  }

  async function loadSimulationStatus() {
    if (!$('simulation-status')) return;
    try {
      renderSimulationStatus(await request('/admin/simulations/status'));
    } catch (error) {
      renderSimulationDisabled(error.message);
    }
  }

  async function startClientSimulation() {
    await runSimulationAction('/admin/simulations/client', 'Simulation client en cours...');
  }

  async function startDriverSimulation() {
    await runSimulationAction('/admin/simulations/driver', 'Simulation chauffeur en cours...');
  }

  async function stopSimulation() {
    await runSimulationAction('/admin/simulations/stop', 'Arret de la simulation...');
  }

  async function runSimulationAction(path, pendingMessage) {
    if (!$('simulation-status')) return;
    if (simulationsDisabled) return;
    setSimulationButtonsDisabled(true);
    $('simulation-status').textContent = pendingMessage;
    try {
      renderSimulationStatus(await request(path, { method: 'POST', body: JSON.stringify({}) }));
    } catch (error) {
      renderSimulationDisabled(error.message);
    } finally {
      if (!simulationsDisabled) setSimulationButtonsDisabled(false);
    }
  }

  function renderSimulationStatus(data) {
    if (!$('simulation-status')) return;
    simulationsDisabled = false;
    $('simulation-status').textContent = data.active
      ? `active ${data.mode || ''}`.trim()
      : 'inactive';
    const logs = data.logs || [];
    $('simulation-logs').innerHTML = logs.length
      ? logs.map((line) => `<div>${escapeHtml(line)}</div>`).join('')
      : 'Aucun log.';
    setSimulationButtonsDisabled(false);
    setSimulationPolling(Boolean(data.active));
  }

  function renderSimulationDisabled(message) {
    if (!$('simulation-status')) return;
    simulationsDisabled = true;
    $('simulation-status').textContent = 'desactive';
    $('simulation-logs').innerHTML = `<div>${escapeHtml(message || 'Dev simulations are disabled. Set ENABLE_DEV_SIMULATIONS=true outside production.')}</div>`;
    setSimulationButtonsDisabled(true);
    setSimulationPolling(false);
  }

  function setSimulationButtonsDisabled(disabled) {
    ['simulation-client', 'simulation-driver', 'simulation-stop'].forEach((id) => {
      if ($(id)) $(id).disabled = disabled;
    });
  }

  function setSimulationPolling(enabled) {
    if (enabled && simulationStatusTimer === null) {
      simulationStatusTimer = window.setInterval(loadSimulationStatus, 3000);
    }
    if (!enabled && simulationStatusTimer !== null) {
      window.clearInterval(simulationStatusTimer);
      simulationStatusTimer = null;
    }
  }

  async function loadPricingAdmin() {
    try {
      setMessage('Chargement du pricing...');
      const [settings, zones, fares, rules] = await Promise.all([
        request('/admin/pricing/settings'),
        request('/admin/pricing/zones'),
        request('/admin/pricing/zone-fares'),
        request('/admin/pricing/time-rules'),
      ]);
      zonesCache = zones; faresCache = fares; timeRulesCache = rules;
      renderPricingSettings(settings);
      renderZones(); renderFareSelectors(); renderFares(); renderTimeRules();
      setMessage('Pricing charge.');
    } catch (error) { setMessage(error.message); }
  }

  function renderPricingSettings(settings) {
    const mode = document.querySelector(`input[name="pricing-mode"][value="${settings.active_mode}"]`);
    if (mode) mode.checked = true;
    $('settings-km').value = settings.price_per_km;
    $('settings-min').value = settings.minimum_price;
    $('settings-commission').value = settings.platform_commission_percent;
    $('settings-long-threshold').value = settings.long_ride_threshold_minutes;
    $('settings-long-min').value = settings.long_ride_minimum_price;
  }

  async function savePricingSettings() {
    const checkedMode = document.querySelector('input[name="pricing-mode"]:checked');
    await request('/admin/pricing/settings', {
      method: 'PUT',
      body: JSON.stringify({
        active_mode: checkedMode?.value || 'mixed',
        price_per_km: $('settings-km').value,
        minimum_price: $('settings-min').value,
        platform_commission_percent: $('settings-commission').value,
        long_ride_threshold_minutes: Number($('settings-long-threshold').value),
        long_ride_minimum_price: $('settings-long-min').value,
      }),
    });
    await loadPricingAdmin();
  }

  function renderZones() {
    if (!$('zones-table')) return;
    $('zones-table').innerHTML = zonesCache.map((zone) => `<tr>
      <td>${zone.name}<br><small>${zone.description || ''}</small></td>
      <td>${zone.radius_km} km</td>
      <td><span class="badge">${zone.is_active ? 'active' : 'off'}</span></td>
      <td><button onclick="AdminApi.openZoneModal(${zone.id})">Modifier</button>
      <button class="ghost" onclick="AdminApi.disableZone(${zone.id})">Desactiver</button></td>
    </tr>`).join('');
  }

  function openZoneModal(id) {
    const zone = zonesCache.find((item) => item.id === id);
    $('zone-id').value = zone?.id || '';
    $('zone-name').value = zone?.name || '';
    $('zone-description').value = zone?.description || '';
    $('zone-lat').value = zone?.latitude || 13.5116;
    $('zone-lng').value = zone?.longitude || 2.1254;
    $('zone-radius').value = zone?.radius_km || 2;
    $('zone-modal').showModal();
  }

  function closeZoneModal() { $('zone-modal').close(); }

  async function saveZone(event) {
    event.preventDefault();
    const id = $('zone-id').value;
    const body = {
      name: $('zone-name').value,
      description: $('zone-description').value,
      base_price: '500',
      price_per_km: '300',
      latitude: Number($('zone-lat').value),
      longitude: Number($('zone-lng').value),
      radius_km: Number($('zone-radius').value),
      is_active: true,
    };
    await request(id ? `/admin/pricing/zones/${id}` : '/admin/pricing/zones', {
      method: id ? 'PUT' : 'POST',
      body: JSON.stringify(body),
    });
    closeZoneModal(); await loadPricingAdmin();
  }

  async function disableZone(id) {
    await request(`/admin/pricing/zones/${id}`, { method: 'DELETE' });
    await loadPricingAdmin();
  }

  function renderFareSelectors() {
    const options = zonesCache.filter((zone) => zone.is_active)
      .map((zone) => `<option value="${zone.id}">${zone.name}</option>`).join('');
    ['fare-origin', 'fare-destination', 'preview-origin', 'preview-destination']
      .forEach((id) => { if ($(id)) $(id).innerHTML = `<option value="">-</option>${options}`; });
  }

  function renderFares() {
    if (!$('fares-table')) return;
    $('fares-table').innerHTML = faresCache.map((fare) => `<tr>
      <td>${fare.origin_zone_name || fare.origin_zone_id}</td>
      <td>${fare.destination_zone_name || fare.destination_zone_id}</td>
      <td><strong>${fare.fixed_price} FCFA</strong></td>
      <td><span class="badge">${fare.is_active ? 'active' : 'off'}</span></td>
      <td><button onclick="AdminApi.openFareModal(${fare.id})">Modifier</button>
      <button class="ghost" onclick="AdminApi.disableFare(${fare.id})">Desactiver</button></td>
    </tr>`).join('');
  }

  function openFareModal(id) {
    const fare = faresCache.find((item) => item.id === id);
    $('fare-id').value = fare?.id || '';
    $('fare-origin').value = fare?.origin_zone_id || '';
    $('fare-destination').value = fare?.destination_zone_id || '';
    $('fare-price').value = fare?.fixed_price || '';
    $('fare-modal').showModal();
  }
  function closeFareModal() { $('fare-modal').close(); }

  async function saveFare(event) {
    event.preventDefault();
    const id = $('fare-id').value;
    await request(id ? `/admin/pricing/zone-fares/${id}` : '/admin/pricing/zone-fares', {
      method: id ? 'PUT' : 'POST',
      body: JSON.stringify({
        origin_zone_id: Number($('fare-origin').value),
        destination_zone_id: Number($('fare-destination').value),
        fixed_price: $('fare-price').value,
        is_active: true,
      }),
    });
    closeFareModal(); await loadPricingAdmin();
  }
  async function disableFare(id) { await request(`/admin/pricing/zone-fares/${id}`, { method: 'DELETE' }); await loadPricingAdmin(); }

  function renderTimeRules() {
    if (!$('time-rules-table')) return;
    $('time-rules-table').innerHTML = timeRulesCache.map((rule) => `<tr>
      <td>${rule.name}</td><td>${rule.start_time} -> ${rule.end_time}</td>
      <td>${rule.surcharge_value} ${rule.surcharge_type === 'percent' ? '%' : 'FCFA'}</td>
      <td><span class="badge">${rule.is_active ? 'active' : 'off'}</span></td>
      <td><button onclick="AdminApi.openTimeRuleModal(${rule.id})">Modifier</button>
      <button class="ghost" onclick="AdminApi.disableTimeRule(${rule.id})">Desactiver</button></td>
    </tr>`).join('');
  }

  function openTimeRuleModal(id) {
    const rule = timeRulesCache.find((item) => item.id === id);
    $('time-rule-id').value = rule?.id || '';
    $('time-rule-name').value = rule?.name || '';
    $('time-rule-start').value = (rule?.start_time || '19:00').slice(0, 5);
    $('time-rule-end').value = (rule?.end_time || '23:59').slice(0, 5);
    $('time-rule-type').value = rule?.surcharge_type || 'percent';
    $('time-rule-value').value = rule?.surcharge_value || 15;
    $('time-rule-modal').showModal();
  }
  function closeTimeRuleModal() { $('time-rule-modal').close(); }

  async function saveTimeRule(event) {
    event.preventDefault();
    const id = $('time-rule-id').value;
    await request(id ? `/admin/pricing/time-rules/${id}` : '/admin/pricing/time-rules', {
      method: id ? 'PUT' : 'POST',
      body: JSON.stringify({
        name: $('time-rule-name').value,
        start_time: $('time-rule-start').value,
        end_time: $('time-rule-end').value,
        surcharge_type: $('time-rule-type').value,
        surcharge_value: $('time-rule-value').value,
        is_active: true,
      }),
    });
    closeTimeRuleModal(); await loadPricingAdmin();
  }
  async function disableTimeRule(id) { await request(`/admin/pricing/time-rules/${id}`, { method: 'DELETE' }); await loadPricingAdmin(); }

  async function previewPricing() {
    const datetime = $('preview-time').value;
    const result = await request('/admin/pricing/preview', {
      method: 'POST',
      body: JSON.stringify({
        distance_km: $('preview-distance').value || null,
        pickup_zone_id: Number($('preview-origin').value) || null,
        dropoff_zone_id: Number($('preview-destination').value) || null,
        request_datetime: datetime ? new Date(datetime).toISOString() : null,
        estimated_duration_minutes: Number($('preview-duration').value) || null,
      }),
    });
    $('preview-result').innerHTML = `<strong>${result.final_estimated_price} FCFA</strong>
      <p>Mode applique : ${result.applied_mode}</p><p>Distance : ${result.distance_km} km</p>
      <p>Tarif zone : ${result.applied_zone_rule ? 'oui' : 'non'}</p>
      <p>Regle horaire : ${result.applied_time_rule?.name || 'aucune'}</p>
      <p>Commission preview : ${result.platform_commission_preview} FCFA</p>`;
  }

  async function loadRides() {
    [ridesCache, reportsCache] = await Promise.all([request('/admin/rides'), request('/admin/reports')]);
    ridesPage = 1;
    renderRides();
  }
  function renderRides() {
    const status = $('status-filter')?.value || '';
    const date = $('ride-date-filter')?.value || '';
    const filtered = applyArchiveFilters(ridesCache, 'created_at').filter((ride) => {
      if (status && ride.status !== status) return false;
      if (date && (ride.created_at || '').slice(0, 10) !== date) return false;
      return true;
    });
    const pageCount = Math.max(1, Math.ceil(filtered.length / ridesPageSize));
    ridesPage = Math.min(ridesPage, pageCount);
    const start = (ridesPage - 1) * ridesPageSize;
    const pageRows = filtered.slice(start, start + ridesPageSize);
    $('rides-table').innerHTML = pageRows.length
      ? pageRows.map((ride) => `<tr>
        <td>${ride.id}</td>
        <td>${escapeHtml(ride.client)}</td>
        <td>${escapeHtml(ride.driver || '-')}</td>
        <td>${ui().badge(ride.status, statusTone(ride.status))}</td>
        <td>${ui().money(priceOf(ride))}</td>
        <td>${escapeHtml(ride.distance_km || '-')}</td>
        <td>${escapeHtml(ride.duration_minutes || '-')}</td>
        <td>${renderReportBadge(ride)}</td>
        <td><button class="ghost" onclick="AdminApi.openRideDetail(${ride.id})">Détail</button></td>
      </tr>`).join('')
      : ui().emptyState('Aucune course à afficher.', 9);
    renderRidePagination(filtered.length, pageCount);
  }
  function renderRidePagination(total, pageCount) {
    if (!$('rides-pagination')) return;
    $('rides-pagination').innerHTML = `<span>${total} course(s) - page ${ridesPage}/${pageCount}</span><div class="actions">
      <button class="ghost" ${ridesPage <= 1 ? 'disabled' : ''} onclick="AdminApi.changeRidesPage(-1)">Précédent</button>
      <button class="ghost" ${ridesPage >= pageCount ? 'disabled' : ''} onclick="AdminApi.changeRidesPage(1)">Suivant</button>
    </div>`;
  }
  function changeRidesPage(delta) {
    ridesPage = Math.max(1, ridesPage + delta);
    renderRides();
  }
  function renderReportBadge(ride) {
    const count = Number(ride.report_count || 0);
    return count ? `<button class="danger-soft" onclick="AdminApi.openReportsModal(${ride.id})">${count} ouvert(s)</button>` : '<span class="badge">0</span>';
  }
  function openRideDetail(rideId) {
    const ride = ridesCache.find((item) => item.id === rideId);
    if (!ride) return;
    const timeline = ['pending', 'offered', 'accepted', 'arrived', 'started', 'completed', 'cancelled'];
    $('ride-detail-content').innerHTML = `
      <div class="form-grid">
        <p><strong>ID</strong><br>${ride.id}</p>
        <p><strong>Client</strong><br>${escapeHtml(ride.client)}</p>
        <p><strong>Chauffeur</strong><br>${escapeHtml(ride.driver || '-')}</p>
        <p><strong>Prix final</strong><br>${ui().money(priceOf(ride))}</p>
      </div>
      <h3>Positions</h3>
      <p><strong>Départ</strong><br>${escapeHtml(ride.pickup_location || '-')}</p>
      <p><strong>Destination</strong><br>${escapeHtml(ride.dropoff_location || '-')}</p>
      <h3>Timeline statut</h3>
      <div class="timeline">${timeline.map((item) => `<div>${ui().badge(item, item === ride.status ? statusTone(item) : 'neutral')}</div>`).join('')}</div>
      <p class="hint">Actions admin en lecture seule sauf traitement support.</p>
    `;
    $('ride-detail-modal').showModal();
  }
  function closeRideDetail() { $('ride-detail-modal').close(); }
  function openReportsModal(rideId) {
    const reports = reportsCache.filter((report) => report.ride_request_id === rideId);
    $('reports-modal-content').innerHTML = reports.length ? reports.map((report) =>
      `<article class="report-card"><strong>${report.reason}</strong><p>${report.description || 'Aucune description.'}</p></article>`).join('') :
      '<p class="hint">Aucun signalement ouvert pour cette course.</p>';
    $('reports-modal').showModal();
  }
  function closeReportsModal() { $('reports-modal').close(); }

  async function loadUsers() { usersCache = await request('/admin/users'); renderUsers(); }
  function setUsersRole(role) {
    usersRoleFilter = role;
    renderUsers();
  }
  function renderUsers() {
    const role = $('role-filter')?.value || usersRoleFilter;
    if ($('users-tab-client')) $('users-tab-client').classList.toggle('active', role === 'client');
    if ($('users-tab-driver')) $('users-tab-driver').classList.toggle('active', role === 'driver');
    const rows = applyArchiveFilters(usersCache, 'created_at').filter((user) => !role || user.role === role);
    $('users-table').innerHTML = rows.length
      ? rows.map((user) => `<tr>
        <td>${user.id}</td>
        <td>${escapeHtml(user.name || '-')}</td>
        <td>${escapeHtml(user.phone_number)}</td>
        <td><span class="badge">${escapeHtml(user.role)}</span></td>
        <td>${ui().badge(user.is_blocked ? 'bloqué' : 'actif', user.is_blocked ? 'danger' : 'neutral')}</td>
        <td>${new Date(user.created_at).toLocaleString()}</td>
        <td><div class="actions">
          <button class="ghost" onclick="AdminApi.openUserProfile(${user.id})">Voir profil</button>
          ${user.is_blocked
            ? `<button class="ghost" onclick="AdminApi.unblockUser(${user.id})">Debloquer</button>`
            : `<button class="danger-soft" onclick="AdminApi.blockUser(${user.id})">Bloquer</button>`}
          <button class="danger-soft" onclick="AdminApi.deleteUser(${user.id})">Supprimer</button>
        </div></td>
      </tr>`).join('')
      : ui().emptyState('Aucun utilisateur à afficher.', 7);
  }
  function openUserProfile(userId) {
    const user = usersCache.find((item) => item.id === userId);
    if (!user) return;
    $('user-profile-content').innerHTML = `
      <div class="form-grid">
        <p><strong>Profil</strong><br>${escapeHtml(user.role)}</p>
        <p><strong>Nom</strong><br>${escapeHtml(user.name || '-')}</p>
        <p><strong>Téléphone</strong><br>${escapeHtml(user.phone_number)}</p>
        <p><strong>Statut</strong><br>${ui().badge(user.is_blocked ? 'bloqué' : 'actif', user.is_blocked ? 'danger' : 'neutral')}</p>
        <p><strong>Inscription</strong><br>${new Date(user.created_at).toLocaleString()}</p>
      </div>`;
    $('user-profile-modal').showModal();
  }
  function closeUserProfile() {
    $('user-profile-modal').close();
  }
  async function blockUser(userId) {
    const user = usersCache.find((item) => item.id === userId);
    const label = user ? `${user.name || user.phone_number || `#${userId}`}` : `#${userId}`;
    if (!window.confirm(`Bloquer ${label} ? Il restera dans la base, mais ne pourra plus se connecter ni utiliser l'app.`)) return;
    try {
      await request(`/admin/users/${userId}/block`, { method: 'POST', body: JSON.stringify({}) });
      await loadUsers();
    } catch (error) {
      window.alert(error.message);
    }
  }
  async function unblockUser(userId) {
    const user = usersCache.find((item) => item.id === userId);
    const label = user ? `${user.name || user.phone_number || `#${userId}`}` : `#${userId}`;
    if (!window.confirm(`Debloquer ${label} ? Il pourra de nouveau se connecter.`)) return;
    try {
      await request(`/admin/users/${userId}/unblock`, { method: 'POST', body: JSON.stringify({}) });
      await loadUsers();
    } catch (error) {
      window.alert(error.message);
    }
  }
  async function deleteUser(userId) {
    const user = usersCache.find((item) => item.id === userId);
    const label = user ? `${user.name || user.phone_number || `#${userId}`}` : `#${userId}`;
    if (!window.confirm(`Supprimer definitivement ${label} ? Cette action est irreversible.`)) return;
    try {
      await request(`/admin/users/${userId}`, { method: 'DELETE' });
      await loadUsers();
    } catch (error) {
      window.alert(error.message);
    }
  }

  async function loadPendingDrivers() {
    try { pendingDriversCache = await request('/admin/drivers/pending'); renderPendingDrivers(); }
    catch (error) { setMessage(error.message); if ($('drivers-table')) $('drivers-table').innerHTML = `<tr><td colspan="5">${error.message}</td></tr>`; }
  }
  async function loadDrivers() {
    try {
      pendingDriversCache = await request('/admin/drivers');
      renderDrivers();
    } catch (error) {
      setMessage(error.message);
      if ($('drivers-table')) $('drivers-table').innerHTML = `<tr><td colspan="6">${escapeHtml(error.message)}</td></tr>`;
    }
  }
  function renderPendingDrivers() {
    if ($('drivers-count')) $('drivers-count').textContent = pendingDriversCache.length;
    $('drivers-table').innerHTML = pendingDriversCache.map((driver) => `<tr>
      <td>${driver.first_name} ${driver.last_name}</td><td>${driver.phone_number}</td>
      <td>${new Date(driver.submitted_at).toLocaleString()}</td><td><span class="badge">${driver.verification_status}</span></td>
      <td><button onclick="AdminApi.openDriverModal(${driver.user_id})">Voir dossier</button></td></tr>`).join('');
  }
  function renderDrivers() {
    if ($('drivers-count')) $('drivers-count').textContent = pendingDriversCache.length;
    const status = $('driver-status-filter')?.value || '';
    const rows = applyArchiveFilters(pendingDriversCache, 'submitted_at').filter((driver) => {
      if (!status) return true;
      if (status === 'blocked') return driver.is_blocked;
      return driver.verification_status === status;
    });
    $('drivers-table').innerHTML = rows.map((driver) => {
      const vehicle = [driver.vehicle_brand, driver.vehicle_model, driver.vehicle_color, driver.plate_number]
        .filter(Boolean)
        .map(escapeHtml)
        .join(' ');
      const docs = [driver.id_card_photo, driver.selfie_photo].filter(Boolean).length;
      return `<tr>
        <td>${escapeHtml(driver.first_name)} ${escapeHtml(driver.last_name)}</td>
        <td>${escapeHtml(driver.phone_number)}</td>
        <td>${docs}/2</td>
        <td>${vehicle || '-'}</td>
        <td>${driver.submitted_at ? new Date(driver.submitted_at).toLocaleString() : '-'}</td>
        <td><span class="badge">${driver.is_blocked ? 'blocked' : escapeHtml(driver.verification_status)}</span></td>
        <td><button onclick="AdminApi.openDriverModal(${driver.user_id})">Consulter</button></td>
      </tr>`;
    }).join('');
  }
  function openDriverModal(userId) {
    const driver = pendingDriversCache.find((item) => item.user_id === userId);
    if (!driver) return;
    const photo = (value, label) => value ? `<figure class="doc-photo"><img src="data:image/jpeg;base64,${value}" alt="${label}"><figcaption>${label}</figcaption></figure>` : `<div class="doc-photo empty">${label}<br>Aucune photo</div>`;
    $('driver-modal-content').innerHTML = `<form class="driver-dossier" onsubmit="AdminApi.saveDriverDossier(event, ${driver.user_id})">
      <input type="hidden" id="driver-user-id" value="${driver.user_id}">
      <div class="form-grid">
        <label>Nom public<input id="driver-user-name" value="${escapeHtml(driver.user_name || `${driver.first_name} ${driver.last_name}`)}"></label>
        <label>Telephone<input id="driver-phone" value="${escapeHtml(driver.phone_number)}"></label>
        <label>Prenom<input id="driver-first-name" value="${escapeHtml(driver.first_name)}"></label>
        <label>Nom<input id="driver-last-name" value="${escapeHtml(driver.last_name)}"></label>
        <label>Adresse<textarea id="driver-address" rows="2">${escapeHtml(driver.address || '')}</textarea></label>
        <label>Marque vehicule<input id="driver-vehicle-brand" value="${escapeHtml(driver.vehicle_brand || '')}"></label>
        <label>Modele<input id="driver-vehicle-model" value="${escapeHtml(driver.vehicle_model || '')}"></label>
        <label>Couleur<input id="driver-vehicle-color" value="${escapeHtml(driver.vehicle_color || '')}"></label>
        <label>Plaque<input id="driver-plate-number" value="${escapeHtml(driver.plate_number || '')}"></label>
      </div>
      <p><span class="badge">${driver.is_blocked ? 'blocked' : escapeHtml(driver.verification_status)}</span></p>
      <div class="driver-docs">${photo(driver.id_card_photo, 'Carte identite')}${photo(driver.selfie_photo, 'Selfie')}</div>
      <label>Raison du rejet</label>
      <textarea id="reject-reason" rows="3">${escapeHtml(driver.rejection_reason || '')}</textarea>
      <div class="actions">
        <button type="button" class="ghost" onclick="AdminApi.closeDriverModal()">Fermer</button>
        <button type="submit">Enregistrer</button>
        <button type="button" class="danger-soft" onclick="AdminApi.rejectDriver(${driver.user_id})">Rejeter</button>
        <button type="button" onclick="AdminApi.verifyDriver(${driver.user_id})">Valider</button>
        ${driver.is_blocked
          ? `<button type="button" class="ghost" onclick="AdminApi.unblockDriver(${driver.user_id})">Debloquer</button>`
          : `<button type="button" class="danger-soft" onclick="AdminApi.blockDriver(${driver.user_id})">Suspendre</button>`}
      </div>
    </form>`;
    $('driver-modal').showModal();
  }
  function closeDriverModal() { $('driver-modal').close(); }
  async function saveDriverDossier(event, userId) {
    event.preventDefault();
    await request(`/admin/drivers/${userId}/profile`, {
      method: 'PUT',
      body: JSON.stringify({
        user_name: $('driver-user-name').value,
        phone_number: $('driver-phone').value,
        first_name: $('driver-first-name').value,
        last_name: $('driver-last-name').value,
        address: $('driver-address').value,
        vehicle_brand: $('driver-vehicle-brand').value,
        vehicle_model: $('driver-vehicle-model').value,
        vehicle_color: $('driver-vehicle-color').value,
        plate_number: $('driver-plate-number').value,
      }),
    });
    closeDriverModal();
    await loadDrivers();
  }
  async function verifyDriver(userId) { await request(`/admin/drivers/${userId}/verify`, { method: 'POST' }); closeDriverModal(); await loadDrivers(); }
  async function rejectDriver(userId) {
    await request(`/admin/drivers/${userId}/reject`, { method: 'POST', body: JSON.stringify({ reason: $('reject-reason')?.value || 'Dossier incomplet' }) });
    closeDriverModal(); await loadDrivers();
  }
  async function blockDriver(userId) {
    const driver = pendingDriversCache.find((item) => item.user_id === userId);
    const label = driver ? `${driver.first_name} ${driver.last_name}` : `#${userId}`;
    if (!window.confirm(`Bloquer ${label} ? Il ne pourra plus utiliser l'app.`)) return;
    await request(`/admin/users/${userId}/block`, { method: 'POST', body: JSON.stringify({}) });
    closeDriverModal();
    await loadDrivers();
  }
  async function unblockDriver(userId) {
    const driver = pendingDriversCache.find((item) => item.user_id === userId);
    const label = driver ? `${driver.first_name} ${driver.last_name}` : `#${userId}`;
    if (!window.confirm(`Debloquer ${label} ? Il pourra de nouveau se connecter.`)) return;
    await request(`/admin/users/${userId}/unblock`, { method: 'POST', body: JSON.stringify({}) });
    closeDriverModal();
    await loadDrivers();
  }

  async function loadPayments() {
    ridesCache = await request('/admin/rides').catch(() => []);
    const completed = applyArchiveFilters(ridesCache, 'created_at').filter((ride) => ride.status === 'completed');
    const totalCash = completed.reduce((sum, ride) => sum + priceOf(ride), 0);
    const commission = Math.round(totalCash * 0.15);
    if ($('payments-metrics')) $('payments-metrics').innerHTML = [
      ui().statCard('Total courses', completed.length),
      ui().statCard('Total cash', ui().money(totalCash)),
      ui().statCard('Commission estimée', ui().money(commission), 'Estimation simple côté admin'),
    ].join('');
    if ($('payments-table')) $('payments-table').innerHTML = completed.length
      ? completed.map((ride) => {
        const cash = priceOf(ride);
        return `<tr><td>${ride.id}</td><td>${escapeHtml(ride.client)}</td><td>${escapeHtml(ride.driver || '-')}</td><td>${ui().badge(ride.status, 'neutral')}</td><td>${ui().money(cash)}</td><td>${ui().money(cash * 0.15)}</td></tr>`;
      }).join('')
      : ui().emptyState('Aucun paiement à afficher.', 6);
  }

  function exportPaymentsCsv() {
    const rows = [['ride_id', 'client', 'driver', 'status', 'cash_total', 'estimated_commission']]
      .concat(ridesCache.filter((ride) => ride.status === 'completed')
        .map((ride) => [ride.id, ride.client, ride.driver || '', ride.status, priceOf(ride), Math.round(priceOf(ride) * 0.15)]));
    const csv = rows.map((row) => row.map((value) => `"${String(value).replaceAll('"', '""')}"`).join(',')).join('\n');
    const link = document.createElement('a');
    link.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
    link.download = 'noor-payments.csv';
    link.click();
    URL.revokeObjectURL(link.href);
  }

  async function loadReportsPage() {
    reportsCache = await request('/admin/reports').catch(() => []);
    renderReportsPage();
  }

  function renderReportsPage() {
    const status = $('report-status-filter')?.value || '';
    const type = $('report-type-filter')?.value || '';
    const rows = applyArchiveFilters(reportsCache, 'created_at').filter((report) => {
      if (status && report.status !== status) return false;
      if (type && report.reported_by_role !== type) return false;
      return true;
    });
    if (!$('reports-table')) return;
    $('reports-table').innerHTML = rows.length
      ? rows.map((report) => `<tr>
        <td>${report.id}</td>
        <td>${report.ride_request_id}</td>
        <td>${escapeHtml(report.reported_by_role)}</td>
        <td>${escapeHtml(report.reported_by)}</td>
        <td>${escapeHtml(report.reason)}</td>
        <td>${ui().badge(report.status, statusTone(report.status))}</td>
        <td>${new Date(report.created_at).toLocaleString()}</td>
      </tr>`).join('')
      : ui().emptyState('Aucun signalement à afficher.', 7);
  }

  async function sendAdminNotification() {
    const target = $('notification-target')?.value || 'clients';
    const message = $('notification-message')?.value.trim() || '';
    if (!message) return setMessage('Message obligatoire.');
    setMessage(`Notification préparée pour ${target}. Le broadcast serveur peut être branché sans changer cette page.`);
  }

  async function loadSettingsPage() {
    try {
      const status = await request('/admin/simulations/status');
      setText('visible-env', status.enabled ? 'development' : 'production ou simulations désactivées');
    } catch (_error) {
      setText('visible-env', 'production ou simulations désactivées');
    }
  }

  return {
    requireAuth, showLoginMessage, login, initAdmin, logout, loadDashboard,
    loadOperationsDashboard, loadSimulationStatus, startClientSimulation, startDriverSimulation, stopSimulation,
    loadPricingAdmin, savePricingSettings,
    openZoneModal, closeZoneModal, saveZone, disableZone,
    openFareModal, closeFareModal, saveFare, disableFare,
    openTimeRuleModal, closeTimeRuleModal, saveTimeRule, disableTimeRule,
    previewPricing, loadRides, renderRides, renderRidePagination, changeRidesPage, openRideDetail, closeRideDetail, openReportsModal, closeReportsModal,
    loadUsers, setUsersRole, renderUsers, openUserProfile, closeUserProfile, blockUser, unblockUser, deleteUser,
    loadDrivers, renderDrivers, loadPendingDrivers, renderPendingDrivers,
    openDriverModal, closeDriverModal, saveDriverDossier, verifyDriver, rejectDriver, blockDriver, unblockDriver,
    loadPayments, exportPaymentsCsv, loadReportsPage, renderReportsPage, applyArchiveFilters, sendAdminNotification, loadSettingsPage,
  };
})();
