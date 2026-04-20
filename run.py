from __future__ import annotations

import argparse
import http.server
import os
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import webbrowser
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = ROOT_DIR / "backend"
MOBILE_DIR = ROOT_DIR / "mobile"
VENV_PYTHON = ROOT_DIR / "venv" / "Scripts" / "python.exe"
FLUTTER_BIN = Path.home() / "Desktop" / "flutter_windows_3.41.7-stable" / "flutter" / "bin" / "flutter.bat"
WEB_BUILD_DIR = MOBILE_DIR / "build" / "web"
PACKAGE_CONFIG = MOBILE_DIR / ".dart_tool" / "package_config.json"

BACKEND_HOST = os.getenv("NOOR_BACKEND_HOST", "127.0.0.1")
BACKEND_PORT = 8000
BACKEND_WORKERS = int(os.getenv("NOOR_BACKEND_WORKERS", "1"))
FRONTEND_HOST = os.getenv("NOOR_FRONTEND_HOST", "127.0.0.1")
FRONTEND_PORT = 3000


class LauncherError(RuntimeError):
    pass


class QuietHttpHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        return


def ensure_venv_python() -> Path:
    if VENV_PYTHON.exists() and Path(sys.executable).resolve() != VENV_PYTHON.resolve():
        os.execv(str(VENV_PYTHON), [str(VENV_PYTHON), str(ROOT_DIR / "run.py"), *sys.argv[1:]])
    return Path(sys.executable)


def port_in_use(host: str, port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(0.5)
        return sock.connect_ex((host, port)) == 0


def wait_for_http(url: str, timeout: int = 40) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                if 200 <= response.status < 500:
                    return True
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            time.sleep(1)
    return False


def access_host(bind_host: str) -> str:
    return "127.0.0.1" if bind_host == "0.0.0.0" else bind_host


def get_lan_ip() -> str | None:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(("8.8.8.8", 80))
            return str(sock.getsockname()[0])
    except OSError:
        return None


def run_command(command: list[str], cwd: Path, title: str) -> None:
    print(f"[{title}] {' '.join(command)}")
    completed = subprocess.run(command, cwd=cwd, check=False)
    if completed.returncode != 0:
        raise LauncherError(f"{title} a echoue avec le code {completed.returncode}.")


def latest_source_mtime() -> float:
    candidates = [
        MOBILE_DIR / "lib",
        MOBILE_DIR / "web",
        MOBILE_DIR / "pubspec.yaml",
    ]
    latest = 0.0

    for candidate in candidates:
        if not candidate.exists():
            continue
        if candidate.is_file():
            latest = max(latest, candidate.stat().st_mtime)
            continue
        for file_path in candidate.rglob("*"):
            if file_path.is_file():
                latest = max(latest, file_path.stat().st_mtime)

    return latest


def should_rebuild_web(force_rebuild: bool) -> bool:
    if force_rebuild:
        return True
    if not WEB_BUILD_DIR.joinpath("index.html").exists():
        return True

    build_mtime = WEB_BUILD_DIR.joinpath("index.html").stat().st_mtime
    return latest_source_mtime() > build_mtime


def ensure_flutter_available() -> None:
    if not FLUTTER_BIN.exists():
        raise LauncherError(
            f"Flutter introuvable: {FLUTTER_BIN}"
        )


def ensure_backend_dependencies(python_bin: Path) -> None:
    requirements = BACKEND_DIR / "requirements.txt"
    if not requirements.exists():
        raise LauncherError("backend/requirements.txt est introuvable.")
    run_command(
        [str(python_bin), "-m", "pip", "install", "-r", str(requirements)],
        cwd=ROOT_DIR,
        title="Backend deps",
    )


def ensure_web_build(force_rebuild: bool) -> None:
    ensure_flutter_available()

    if not PACKAGE_CONFIG.exists():
        run_command(
            [str(FLUTTER_BIN), "pub", "get"],
            cwd=MOBILE_DIR,
            title="Flutter pub get",
        )

    if should_rebuild_web(force_rebuild):
        run_command(
            [str(FLUTTER_BIN), "build", "web", "--release"],
            cwd=MOBILE_DIR,
            title="Flutter build web",
        )

    if not WEB_BUILD_DIR.joinpath("index.html").exists():
        raise LauncherError("Le build web n'a pas ete genere.")


def start_backend(python_bin: Path) -> subprocess.Popen[str] | None:
    backend_url = f"http://{access_host(BACKEND_HOST)}:{BACKEND_PORT}/"

    if port_in_use(access_host(BACKEND_HOST), BACKEND_PORT):
        if wait_for_http(backend_url, timeout=3):
            print(f"[Backend] deja actif sur {backend_url}")
            return None
        raise LauncherError(
            f"Le port backend {BACKEND_PORT} est deja occupe, mais le service ne repond pas correctement."
        )

    uvicorn_command = [
        str(python_bin),
        "-m",
        "uvicorn",
        "app.main:app",
        "--host",
        BACKEND_HOST,
        "--port",
        str(BACKEND_PORT),
        "--http",
        "httptools",
    ]
    if sys.platform != "win32":
        uvicorn_command.extend(["--loop", "uvloop"])
    if BACKEND_WORKERS > 1:
        uvicorn_command.extend(["--workers", str(BACKEND_WORKERS)])

    process = subprocess.Popen(uvicorn_command, cwd=BACKEND_DIR)

    if not wait_for_http(backend_url, timeout=25):
        process.terminate()
        raise LauncherError("Le backend n'a pas demarre correctement.")

    print(f"[Backend] actif sur {backend_url}")
    return process


def start_frontend_server() -> tuple[http.server.ThreadingHTTPServer | None, threading.Thread | None]:
    frontend_url = f"http://{access_host(FRONTEND_HOST)}:{FRONTEND_PORT}/"

    if port_in_use(access_host(FRONTEND_HOST), FRONTEND_PORT):
        if wait_for_http(frontend_url, timeout=3):
            print(f"[Frontend] deja actif sur {frontend_url}")
            return None, None
        raise LauncherError(
            f"Le port frontend {FRONTEND_PORT} est deja occupe, mais le service ne repond pas correctement."
        )

    handler = lambda *args, **kwargs: QuietHttpHandler(*args, directory=str(WEB_BUILD_DIR), **kwargs)
    server = http.server.ThreadingHTTPServer((FRONTEND_HOST, FRONTEND_PORT), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    if not wait_for_http(frontend_url, timeout=5):
        server.shutdown()
        raise LauncherError("Le serveur frontend n'a pas pu demarrer.")

    print(f"[Frontend] actif sur {frontend_url}")
    return server, thread


def print_audit() -> None:
    print("Audit du demarrage actuel")
    print("- Tu avais plusieurs points d'entree implicites: backend/main.py, PLAY_NOOR.bat, commandes PowerShell manuelles.")
    print("- Le frontend etait lance via un .bat avec logique de build, attente fixe et dependance forte au chemin Flutter.")
    print("- Le navigateur pouvait s'ouvrir trop tot, avant que le build web soit vraiment servi.")
    print("- Le backend pouvait etre lance de plusieurs facons, dont certaines moins propres que uvicorn.")
    print("- Le nouveau point d'entree officiel devient run.py.")
    print()


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Demarrage unifie Noor Express")
    parser.add_argument("--lan", action="store_true", help="Expose backend/frontend au reseau local.")
    parser.add_argument("--no-browser", action="store_true", help="N'ouvre pas le navigateur automatiquement.")
    parser.add_argument("--skip-deps", action="store_true", help="Ne reinstalle pas les dependances backend.")
    parser.add_argument("--rebuild-web", action="store_true", help="Force un rebuild web release.")
    return parser


def main() -> int:
    global BACKEND_HOST, FRONTEND_HOST

    args = build_arg_parser().parse_args()
    python_bin = ensure_venv_python()

    if args.lan:
        BACKEND_HOST = "0.0.0.0"
        FRONTEND_HOST = "0.0.0.0"

    print_audit()

    if not args.skip_deps:
        ensure_backend_dependencies(python_bin)

    ensure_web_build(force_rebuild=args.rebuild_web)

    backend_process = start_backend(python_bin)
    frontend_server, _ = start_frontend_server()

    frontend_url = f"http://{access_host(FRONTEND_HOST)}:{FRONTEND_PORT}/"
    backend_url = f"http://{access_host(BACKEND_HOST)}:{BACKEND_PORT}/"

    print()
    print("Noor Express est pret")
    print(f"- Frontend: {frontend_url}")
    print(f"- Backend:  {backend_url}")
    print("- Fichier principal de demarrage: run.py")
    print("- Double-clic possible via PLAY_NOOR.bat")
    print("- Arret: Ctrl + C dans cette fenetre")
    if args.lan:
        lan_ip = get_lan_ip()
        print("- Mode LAN actif: telephone autorise si le pare-feu Windows laisse passer le port 8000.")
        if lan_ip:
            print(f"- Backend pour APK telephone: http://{lan_ip}:{BACKEND_PORT}")
            print(
                "- Build APK telephone: flutter build apk --release --shrink "
                f"--dart-define=NOOR_API_BASE_URL=http://{lan_ip}:{BACKEND_PORT}"
            )
    print()

    if not args.no_browser:
        webbrowser.open(frontend_url)

    try:
        while True:
            if backend_process is not None and backend_process.poll() is not None:
                raise LauncherError("Le backend s'est arrete de maniere inattendue.")
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nArret de Noor Express...")
    finally:
        if frontend_server is not None:
            frontend_server.shutdown()
            frontend_server.server_close()
        if backend_process is not None and backend_process.poll() is None:
            backend_process.send_signal(signal.SIGTERM)
            try:
                backend_process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                backend_process.kill()

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except LauncherError as error:
        print(f"\nErreur de lancement: {error}")
        raise SystemExit(1)
