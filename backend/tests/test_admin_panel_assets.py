from pathlib import Path
import re
import unittest


BACKEND_DIR = Path(__file__).resolve().parents[1]
ADMIN_PANEL_DIR = BACKEND_DIR / "admin_panel"


class AdminPanelAssetsTest(unittest.TestCase):
    EXPECTED_PAGES = {
        "dashboard.html",
        "rides.html",
        "users.html",
        "drivers.html",
        "zones.html",
        "payments.html",
        "reports.html",
        "notifications.html",
        "simulations.html",
        "settings.html",
    }

    def test_admin_pages_cache_bust_shared_api_script(self) -> None:
        html_files = sorted(ADMIN_PANEL_DIR.glob("*.html"))
        self.assertTrue(html_files)

        missing_api_script = []
        unversioned_api_scripts = []

        for html_file in html_files:
            content = html_file.read_text(encoding="utf-8")
            api_scripts = re.findall(r'<script\s+src="([^"]*api\.js[^"]*)"', content)
            if not api_scripts:
                missing_api_script.append(html_file.name)
            for script_src in api_scripts:
                if "?v=" not in script_src:
                    unversioned_api_scripts.append((html_file.name, script_src))

        self.assertEqual([], missing_api_script)
        self.assertEqual([], unversioned_api_scripts)

    def test_admin_pages_define_local_favicon(self) -> None:
        favicon_path = ADMIN_PANEL_DIR / "assets" / "favicon.svg"
        html_files = sorted(ADMIN_PANEL_DIR.glob("*.html"))

        self.assertTrue(favicon_path.exists())
        for html_file in html_files:
            content = html_file.read_text(encoding="utf-8")
            self.assertIn('<link rel="icon" href="assets/favicon.svg" type="image/svg+xml">', content)

    def test_admin_panel_has_production_navigation_pages(self) -> None:
        existing_pages = {path.name for path in ADMIN_PANEL_DIR.glob("*.html")}
        self.assertTrue(self.EXPECTED_PAGES.issubset(existing_pages))

        admin_ui = (ADMIN_PANEL_DIR / "assets" / "admin-ui.js").read_text(encoding="utf-8")
        for label in [
            "Tableau de bord",
            "Courses",
            "Utilisateurs",
            "Chauffeurs à valider",
            "Zones & tarifs",
            "Paiements",
            "Signalements",
            "Notifications",
            "Simulations DEV",
            "Paramètres",
        ]:
            self.assertIn(label, admin_ui)

        for page_name in self.EXPECTED_PAGES:
            content = (ADMIN_PANEL_DIR / page_name).read_text(encoding="utf-8")
            self.assertIn('data-admin-sidebar', content)
            self.assertIn('assets/admin-ui.js?v=', content)

    def test_admin_panel_has_theme_logo_and_archive_filters(self) -> None:
        admin_ui = (ADMIN_PANEL_DIR / "assets" / "admin-ui.js").read_text(encoding="utf-8")
        style_css = (ADMIN_PANEL_DIR / "assets" / "style.css").read_text(encoding="utf-8")
        api_js = (ADMIN_PANEL_DIR / "assets" / "api.js").read_text(encoding="utf-8")

        self.assertIn("logo-mark", admin_ui)
        self.assertIn("theme-toggle", admin_ui)
        self.assertIn("toggleTheme", admin_ui)
        self.assertIn('[data-theme="dark"]', style_css)
        self.assertIn("applyArchiveFilters", api_js)

        for page_name in ["rides.html", "users.html", "drivers.html", "payments.html", "reports.html"]:
            content = (ADMIN_PANEL_DIR / page_name).read_text(encoding="utf-8")
            self.assertIn('data-archive-year', content)
            self.assertIn('data-archive-month', content)

    def test_users_page_uses_profile_modal_not_browser_alert(self) -> None:
        users_html = (ADMIN_PANEL_DIR / "users.html").read_text(encoding="utf-8")
        api_js = (ADMIN_PANEL_DIR / "assets" / "api.js").read_text(encoding="utf-8")

        self.assertIn('id="user-profile-modal"', users_html)
        self.assertIn("user-profile-content", users_html)
        self.assertIn("openUserProfile", api_js)
        self.assertIn("closeUserProfile", api_js)
        self.assertNotIn("window.alert(`Profil", api_js)

    def test_dashboard_exposes_operations_metrics(self) -> None:
        dashboard_html = (ADMIN_PANEL_DIR / "dashboard.html").read_text(encoding="utf-8")
        api_js = (ADMIN_PANEL_DIR / "assets" / "api.js").read_text(encoding="utf-8")

        self.assertIn("Courses aujourd", dashboard_html)
        self.assertIn("Chauffeurs en ligne", dashboard_html)
        self.assertIn("Taux d'annulation", dashboard_html)
        self.assertIn("loadOperationsDashboard", api_js)

    def test_login_page_hides_admin_bootstrap_shortcuts(self) -> None:
        index_html = (ADMIN_PANEL_DIR / "index.html").read_text(encoding="utf-8")

        self.assertNotIn("admin123", index_html)
        self.assertNotIn("Créer le premier admin", index_html)
        self.assertNotIn("init-admin", index_html)
        self.assertIn("Identifiant (email ou téléphone)", index_html)
        self.assertIn("Mot de passe", index_html)
        self.assertIn("Se connecter", index_html)

    def test_rides_page_exposes_filters_pagination_and_detail(self) -> None:
        rides_html = (ADMIN_PANEL_DIR / "rides.html").read_text(encoding="utf-8")
        api_js = (ADMIN_PANEL_DIR / "assets" / "api.js").read_text(encoding="utf-8")

        self.assertIn('id="ride-date-filter"', rides_html)
        self.assertIn('id="ride-detail-modal"', rides_html)
        self.assertIn("renderRidePagination", api_js)
        self.assertIn("openRideDetail", api_js)

    def test_simulations_page_uses_dev_status_gate(self) -> None:
        simulations_html = (ADMIN_PANEL_DIR / "simulations.html").read_text(encoding="utf-8")
        api_js = (ADMIN_PANEL_DIR / "assets" / "api.js").read_text(encoding="utf-8")

        self.assertIn("AdminApi.loadSimulationStatus()", simulations_html)
        self.assertIn("renderSimulationDisabled", api_js)
        self.assertIn("Simulations de developpement desactivees", api_js)

    def test_users_page_exposes_user_management_actions(self) -> None:
        users_html = (ADMIN_PANEL_DIR / "users.html").read_text(encoding="utf-8")
        api_js = (ADMIN_PANEL_DIR / "assets" / "api.js").read_text(encoding="utf-8")

        self.assertIn("<th>Actions</th>", users_html)
        self.assertIn("AdminApi.blockUser", api_js)
        self.assertIn("AdminApi.deleteUser", api_js)
        self.assertIn("/admin/users/${userId}/block", api_js)
        self.assertIn("/admin/users/${userId}", api_js)

    def test_drivers_page_exposes_dossier_management_actions(self) -> None:
        drivers_html = (ADMIN_PANEL_DIR / "drivers.html").read_text(encoding="utf-8")
        api_js = (ADMIN_PANEL_DIR / "assets" / "api.js").read_text(encoding="utf-8")

        self.assertIn("AdminApi.loadDrivers()", drivers_html)
        self.assertIn("id=\"driver-status-filter\"", drivers_html)
        self.assertIn("AdminApi.saveDriverDossier", api_js)
        self.assertIn("AdminApi.blockDriver", api_js)
        self.assertIn("AdminApi.unblockDriver", api_js)
        self.assertIn("/admin/drivers/${userId}/profile", api_js)
        self.assertIn("/admin/users/${userId}/block", api_js)

    def test_payments_page_exposes_driver_ledger_filter(self) -> None:
        payments_html = (ADMIN_PANEL_DIR / "payments.html").read_text(encoding="utf-8")
        api_js = (ADMIN_PANEL_DIR / "assets" / "api.js").read_text(encoding="utf-8")

        self.assertIn('id="payments-driver-filter"', payments_html)
        self.assertIn("ensurePaymentsDriverFilterLoaded", api_js)
        self.assertIn("selectedPaymentDriverId", api_js)
        self.assertIn("driver_id", api_js)

    def test_notifications_page_exposes_broadcast_form_and_history(self) -> None:
        notifications_html = (ADMIN_PANEL_DIR / "notifications.html").read_text(
            encoding="utf-8"
        )
        api_js = (ADMIN_PANEL_DIR / "assets" / "api.js").read_text(encoding="utf-8")

        self.assertIn('id="notification-target"', notifications_html)
        self.assertIn('id="notification-estimated-recipients"', notifications_html)
        self.assertIn('id="notifications-history-body"', notifications_html)
        self.assertIn('id="firebase-warning-panel"', notifications_html)
        self.assertIn("AdminApi.loadNotificationsPage()", notifications_html)
        self.assertIn("/admin/notifications/broadcast", api_js)
        self.assertIn("/admin/notifications/history", api_js)
        self.assertIn("/admin/notifications/estimate", api_js)
        self.assertIn("notificationStatusLabel", api_js)
        self.assertIn("setFirebaseWarning", api_js)


if __name__ == "__main__":
    unittest.main()

