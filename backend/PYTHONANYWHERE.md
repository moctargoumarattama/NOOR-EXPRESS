# PythonAnywhere deployment temporaire

Ce projet peut tourner sur PythonAnywhere en mode temporaire, avec SQLite et sans Redis.

## Base de données

- `DATABASE_URL=sqlite+aiosqlite:///NOOREXPRESS.BD`
- Le fichier SQLite sera créé dans le dossier `backend/`

## Fichier WSGI

- Utiliser `backend/wsgi.py` comme point d'entrée
- Le callable exposé est `application`
- Ce fichier force SQLite même si un ancien `.env` distant pointe encore vers MySQL

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
- `RUN_SCHEMA_BOOTSTRAP_ON_STARTUP=0`
- `RUN_SCHEMA_CREATE_ALL_ON_STARTUP=1`
- `FORCE_SQLITE=1`
- `SKIP_FIREBASE_STARTUP_CHECK=1`

## Limites

- Le mode WSGI ne couvre pas les WebSockets temps réel.
- C'est donc adapté pour un déploiement temporaire ou partiel, pas pour valider tout le temps réel en production.
- Le wrapper WSGI charge l'app FastAPI de manière paresseuse pour réduire le temps de reload.
