from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Response,
    UploadFile,
    status,
)
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import get_current_client, get_current_user
from app.db.database import get_db_session
from app.models.user import User
from app.schemas.user import (
    ClientProfileRead,
    ClientProfileUpdate,
    SavedAddressCreate,
    SavedAddressRead,
    SavedAddressUpdate,
    UserCreate,
    UserRead,
)
from app.services.user_service import (
    UserPhoneAlreadyExistsError,
    create_saved_address,
    create_user,
    delete_current_user_account,
    delete_saved_address,
    get_client_profile,
    get_user_by_id,
    list_saved_addresses,
    update_saved_address,
    update_client_profile,
    update_current_user_profile,
)

router = APIRouter(prefix="/users", tags=["users"])
config_router = APIRouter(prefix="/config", tags=["config"])
legal_router = APIRouter(prefix="/legal", tags=["legal"])

LEGAL_TERMS_SECTIONS: list[tuple[str, list[str]]] = [
    (
        "1. Description du service",
        [
            "Noor Express met en relation des passagers et des chauffeurs "
            "de voitures privees a Niamey.",
            "L'application facilite la demande de course, la negociation "
            "du prix et le suivi du trajet.",
        ],
    ),
    (
        "2. Obligations des utilisateurs",
        [
            "Fournir des informations exactes (identite, numero de "
            "telephone, details de course).",
            "Respecter les lois en vigueur au Niger ainsi que les autres "
            "utilisateurs de la plateforme.",
            "Ne pas utiliser le service pour des activites frauduleuses, "
            "dangereuses ou interdites.",
        ],
    ),
    (
        "3. Limitations de responsabilite",
        [
            "Noor Express agit comme intermediaire technologique entre "
            "passagers et chauffeurs.",
            "Noor Express ne peut garantir l'absence totale "
            "d'indisponibilite, de retard, ou d'evenement externe pendant "
            "une course.",
        ],
    ),
    (
        "4. Droit applicable",
        [
            "Les presentes CGU sont regies par le droit en vigueur au Niger.",
            "Tout litige releve prioritairement d'une resolution amiable, "
            "puis des juridictions competentes du Niger.",
        ],
    ),
]

LEGAL_PRIVACY_SECTIONS: list[tuple[str, list[str]]] = [
    (
        "1. Donnees collectees",
        [
            "Numero de telephone pour l'authentification et la gestion du compte.",
            "Position GPS pendant la recherche, le suivi et l'execution des courses.",
            "Donnees de courses (points de depart/arrivee, horodatage, "
            "prix, statut).",
        ],
    ),
    (
        "2. Utilisation des donnees",
        [
            "Fournir et securiser le service de transport Noor Express.",
            "Ameliorer la qualite du service, prevenir la fraude et traiter "
            "les incidents.",
            "Assurer le support client et la conformite administrative.",
        ],
    ),
    (
        "3. Duree de conservation",
        [
            "Les donnees necessaires a l'operation du compte sont conservees "
            "tant que le compte est actif.",
            "Les donnees de courses peuvent etre conservees apres suppression "
            "du compte sous forme anonymisee pour l'integrite financiere "
            "et la conformite.",
        ],
    ),
    (
        "4. Droit de suppression",
        [
            "Vous pouvez supprimer votre compte depuis l'application (Parametres > "
            "Supprimer mon compte).",
            "Lors de la suppression, les donnees personnelles sont anonymisees "
            "conformement a la politique Noor Express.",
        ],
    ),
]


@config_router.get("/support", response_model=dict[str, str])
async def support_config_endpoint() -> dict[str, str]:
    whatsapp_number = settings.SUPPORT_WHATSAPP_NUMBER.strip()
    support_hours = settings.SUPPORT_HOURS.strip()
    return {
        "whatsapp_number": whatsapp_number,
        "support_hours": support_hours,
    }


@legal_router.get("/terms", response_class=HTMLResponse)
async def legal_terms_endpoint() -> HTMLResponse:
    return HTMLResponse(content=_legal_terms_html())


@legal_router.get("/privacy", response_class=HTMLResponse)
async def legal_privacy_endpoint() -> HTMLResponse:
    return HTMLResponse(content=_legal_privacy_html())


@router.post("/", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def create_user_endpoint(
    user_in: UserCreate,
    session: AsyncSession = Depends(get_db_session),
) -> UserRead:
    try:
        user = await create_user(session, user_in)
    except UserPhoneAlreadyExistsError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    return UserRead.model_validate(user)


@router.get("/me", response_model=UserRead)
async def get_current_user_endpoint(
    current_user: User = Depends(get_current_user),
) -> UserRead:
    return UserRead.model_validate(current_user)


@router.patch("/me", response_model=UserRead)
async def update_current_user_endpoint(
    first_name: str | None = Form(default=None),
    phone_number: str | None = Form(default=None),
    profile_photo: UploadFile | None = File(default=None),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> UserRead:
    updated_user = await update_current_user_profile(
        session,
        current_user,
        first_name=first_name,
        phone_number=phone_number,
        profile_photo=profile_photo,
    )
    return UserRead.model_validate(updated_user)


@router.get("/me/profile", response_model=ClientProfileRead)
async def get_current_client_profile_endpoint(
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> ClientProfileRead:
    profile = await get_client_profile(session, current_user.id)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Client profile not found",
        )
    return profile


@router.put("/me/profile", response_model=ClientProfileRead)
async def update_current_client_profile_endpoint(
    profile_in: ClientProfileUpdate,
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> ClientProfileRead:
    profile = await update_client_profile(session, current_user.id, profile_in)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Client profile not found",
        )
    return profile


@router.get("/me/addresses", response_model=list[SavedAddressRead])
async def list_current_client_saved_addresses_endpoint(
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> list[SavedAddressRead]:
    saved_addresses = await list_saved_addresses(session, current_user.id)
    return [SavedAddressRead.model_validate(item) for item in saved_addresses]


@router.post(
    "/me/addresses",
    response_model=SavedAddressRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_current_client_saved_address_endpoint(
    address_in: SavedAddressCreate,
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> SavedAddressRead:
    saved_address = await create_saved_address(session, current_user.id, address_in)
    return SavedAddressRead.model_validate(saved_address)


@router.put("/me/addresses/{saved_address_id}", response_model=SavedAddressRead)
async def update_current_client_saved_address_endpoint(
    saved_address_id: int,
    address_in: SavedAddressUpdate,
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> SavedAddressRead:
    saved_address = await update_saved_address(
        session,
        current_user.id,
        saved_address_id,
        address_in,
    )
    return SavedAddressRead.model_validate(saved_address)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_current_user_account_endpoint(
    reason: str | None = None,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    await delete_current_user_account(
        session,
        current_user,
        deletion_reason=reason,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/me/addresses/{saved_address_id}", status_code=status.HTTP_204_NO_CONTENT
)
async def delete_current_client_saved_address_endpoint(
    saved_address_id: int,
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    await delete_saved_address(session, current_user.id, saved_address_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{user_id}", response_model=UserRead)
async def get_user_endpoint(
    user_id: int,
    session: AsyncSession = Depends(get_db_session),
) -> UserRead:
    user = await get_user_by_id(session, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return UserRead.model_validate(user)


def _legal_terms_html() -> str:
    return _legal_page_html(
        title="Conditions Generales d'Utilisation",
        subtitle="Noor Express - Service de VTC prive a Niamey, Niger",
        updated_on="02 mai 2026",
        sections=LEGAL_TERMS_SECTIONS,
    )


def _legal_privacy_html() -> str:
    return _legal_page_html(
        title="Politique de Confidentialite",
        subtitle="Noor Express - Donnees personnelles a Niamey, Niger",
        updated_on="02 mai 2026",
        sections=LEGAL_PRIVACY_SECTIONS,
    )


def _legal_page_html(
    *,
    title: str,
    subtitle: str,
    updated_on: str,
    sections: list[tuple[str, list[str]]],
) -> str:
    sections_html = "".join(
        _legal_section_html(heading=heading, paragraphs=paragraphs)
        for heading, paragraphs in sections
    )
    return f"""<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{title} - Noor Express</title>
  <style>
    :root {{ color-scheme: light; }}
    body {{ margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f6f7fb; color: #182033; }}
    main {{ max-width: 820px; margin: 0 auto; padding: 20px 16px 28px; }}
    article {{ background: #ffffff; border-radius: 16px; padding: 18px 16px; box-shadow: 0 8px 28px rgba(8, 20, 38, 0.08); }}
    h1 {{ margin: 0 0 8px; font-size: 1.4rem; line-height: 1.3; }}
    .meta {{ margin: 0 0 18px; color: #5d697f; font-size: 0.95rem; }}
    h2 {{ margin: 18px 0 8px; font-size: 1.08rem; }}
    p {{ margin: 0 0 8px; line-height: 1.55; }}
  </style>
</head>
<body>
  <main>
    <article>
      <h1>{title}</h1>
      <p class="meta">{subtitle}<br />Derniere mise a jour : {updated_on}</p>
      {sections_html}
    </article>
  </main>
</body>
</html>"""


def _legal_section_html(*, heading: str, paragraphs: list[str]) -> str:
    paragraphs_html = "".join(f"<p>{paragraph}</p>" for paragraph in paragraphs)
    return f"<section><h2>{heading}</h2>{paragraphs_html}</section>"
