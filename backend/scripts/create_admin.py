import argparse
import asyncio
import getpass
from pathlib import Path
import sys

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.database import AsyncSessionLocal
from app.services.admin_service import AdminAlreadyExistsError, create_admin


async def _create_first_admin(username: str, password: str) -> int:
    async with AsyncSessionLocal() as session:
        try:
            admin = await create_admin(session, username=username, password=password)
        except AdminAlreadyExistsError:
            print("Echec: un administrateur existe deja dans la base.")
            return 1

    print(f"Admin cree avec succes: {admin.username}")
    return 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Creation locale du premier administrateur Noor Express."
    )
    parser.add_argument(
        "--username",
        required=True,
        help="Identifiant admin (email, telephone, ou pseudo).",
    )
    parser.add_argument(
        "--password",
        help="Mot de passe admin. Si absent, il est demande de facon securisee.",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    password = args.password or getpass.getpass("Mot de passe admin: ")
    if not password.strip():
        print("Echec: le mot de passe est obligatoire.")
        return 1
    return asyncio.run(_create_first_admin(args.username.strip(), password))


if __name__ == "__main__":
    raise SystemExit(main())
