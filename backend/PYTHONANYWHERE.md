# PythonAnywhere deployment temporaire

Ce projet peut tourner sur PythonAnywhere en mode temporaire, avec SQLite et sans Redis.

## Base de données

- `DATABASE_URL=sqlite+aiosqlite:///NOOREXPRESS.BD`
- Le fichier SQLite sera créé dans le dossier `backend/`

## Fichier WSGI

- Utiliser `backend/wsgi.py` comme point d'entrée
- Le callable exposé est `application`

## Dépendances

- Installer `-r backend/requirements.txt`

## Fichiers statiques

Dans l'onglet Web de PythonAnywhere, déclarer:

- `/admin-panel` -> dossier `backend/admin_panel`
- `/uploads` -> dossier `backend/uploads`

## Variables d'environnement minimales

- `SECRET_KEY`
- `ADMIN_SECRET_KEY`
- `DATABASE_URL`

## Limites

- Le mode WSGI ne couvre pas les WebSockets temps réel.
- C'est donc adapté pour un déploiement temporaire ou partiel, pas pour valider tout le temps réel en production.
