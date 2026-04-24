const AdminApi = (() => {
  const API_BASE = window.location.origin;
  let zonesCache = [];
  let faresCache = [];
  let timeRulesCache = [];
  let ridesCache = [];
  let reportsCache = [];
  let usersCache = [];
  let pendingDriversCache = [];

  const token = () => localStorage.getItem('noor_admin_token');
  const $ = (id) => document.getElementById(id);
  const setMessage = (text) => { if ($('message')) $('message').textContent = text; };
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

  async function loadDashboard() {
    const data = await request('/admin/dashboard');
    const stats = [
      ['Total courses', data.total_rides],
      ['En cours', data.accepted + data.started],
      ['Completees', data.completed],
      ['Annulees', data.cancelled],
      ['Revenus', `${Math.round(data.revenue)} FCFA`],
      ['Users', data.total_users],
    ];
    $('stats').innerHTML = stats.map(([label, value]) =>
      `<article class="card">${label}<strong>${value}</strong></article>`).join('');
    $('top-drivers').innerHTML = (data.top_drivers || []).map((driver) =>
      `<tr><td>${driver.phone_number}</td><td>${driver.completed_rides}</td><td>${driver.total_earnings} FCFA</td></tr>`).join('');
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
    renderRides();
  }
  function renderRides() {
    const status = $('status-filter')?.value || '';
    $('rides-table').innerHTML = ridesCache.filter((ride) => !status || ride.status === status)
      .map((ride) => `<tr><td>${ride.id}</td><td>${ride.client}</td><td>${ride.driver || '-'}</td>
      <td>${ride.pickup_location}</td><td>${ride.dropoff_location}</td>
      <td>${ride.final_price || ride.agreed_price || ride.estimated_price} FCFA</td><td><span class="badge">${ride.status}</span></td>
      <td>${renderReportBadge(ride)}</td><td>${new Date(ride.created_at).toLocaleString()}</td></tr>`).join('');
  }
  function renderReportBadge(ride) {
    const count = Number(ride.report_count || 0);
    return count ? `<button class="danger-soft" onclick="AdminApi.openReportsModal(${ride.id})">${count} ouvert(s)</button>` : '<span class="badge">0</span>';
  }
  function openReportsModal(rideId) {
    const reports = reportsCache.filter((report) => report.ride_request_id === rideId);
    $('reports-modal-content').innerHTML = reports.length ? reports.map((report) =>
      `<article class="report-card"><strong>${report.reason}</strong><p>${report.description || 'Aucune description.'}</p></article>`).join('') :
      '<p class="hint">Aucun signalement ouvert pour cette course.</p>';
    $('reports-modal').showModal();
  }
  function closeReportsModal() { $('reports-modal').close(); }

  async function loadUsers() { usersCache = await request('/admin/users'); renderUsers(); }
  function renderUsers() {
    const role = $('role-filter')?.value || '';
    $('users-table').innerHTML = usersCache.filter((user) => !role || user.role === role)
      .map((user) => `<tr><td>${user.id}</td><td>${user.name || '-'}</td><td>${user.phone_number}</td><td><span class="badge">${user.role}</span></td><td>${new Date(user.created_at).toLocaleString()}</td></tr>`).join('');
  }

  async function loadPendingDrivers() {
    try { pendingDriversCache = await request('/admin/drivers/pending'); renderPendingDrivers(); }
    catch (error) { setMessage(error.message); if ($('drivers-table')) $('drivers-table').innerHTML = `<tr><td colspan="5">${error.message}</td></tr>`; }
  }
  function renderPendingDrivers() {
    if ($('drivers-count')) $('drivers-count').textContent = pendingDriversCache.length;
    $('drivers-table').innerHTML = pendingDriversCache.map((driver) => `<tr>
      <td>${driver.first_name} ${driver.last_name}</td><td>${driver.phone_number}</td>
      <td>${new Date(driver.submitted_at).toLocaleString()}</td><td><span class="badge">${driver.verification_status}</span></td>
      <td><button onclick="AdminApi.openDriverModal(${driver.user_id})">Voir dossier</button></td></tr>`).join('');
  }
  function openDriverModal(userId) {
    const driver = pendingDriversCache.find((item) => item.user_id === userId);
    if (!driver) return;
    const photo = (value, label) => value ? `<figure class="doc-photo"><img src="data:image/jpeg;base64,${value}" alt="${label}"><figcaption>${label}</figcaption></figure>` : `<div class="doc-photo empty">${label}<br>Aucune photo</div>`;
    $('driver-modal-content').innerHTML = `<div class="driver-dossier"><p><strong>${driver.first_name} ${driver.last_name}</strong></p><p>${driver.phone_number}</p><p>${driver.address || 'Adresse non renseignee.'}</p><div class="driver-docs">${photo(driver.id_card_photo, 'Carte identite')}${photo(driver.selfie_photo, 'Selfie')}</div><label>Raison du rejet</label><textarea id="reject-reason" rows="3"></textarea><div class="actions"><button class="ghost" onclick="AdminApi.closeDriverModal()">Fermer</button><button class="danger-soft" onclick="AdminApi.rejectDriver(${driver.user_id})">Rejeter</button><button onclick="AdminApi.verifyDriver(${driver.user_id})">Valider</button></div></div>`;
    $('driver-modal').showModal();
  }
  function closeDriverModal() { $('driver-modal').close(); }
  async function verifyDriver(userId) { await request(`/admin/drivers/${userId}/verify`, { method: 'POST' }); closeDriverModal(); await loadPendingDrivers(); }
  async function rejectDriver(userId) {
    await request(`/admin/drivers/${userId}/reject`, { method: 'POST', body: JSON.stringify({ reason: $('reject-reason')?.value || 'Dossier incomplet' }) });
    closeDriverModal(); await loadPendingDrivers();
  }

  return {
    requireAuth, showLoginMessage, login, initAdmin, logout, loadDashboard,
    loadPricingAdmin, savePricingSettings,
    openZoneModal, closeZoneModal, saveZone, disableZone,
    openFareModal, closeFareModal, saveFare, disableFare,
    openTimeRuleModal, closeTimeRuleModal, saveTimeRule, disableTimeRule,
    previewPricing, loadRides, renderRides, openReportsModal, closeReportsModal,
    loadUsers, renderUsers, loadPendingDrivers, renderPendingDrivers,
    openDriverModal, closeDriverModal, verifyDriver, rejectDriver,
  };
})();
