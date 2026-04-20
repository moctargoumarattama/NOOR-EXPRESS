# Noor Express

## Demarrage rapide

```powershell
python run.py
```

## Build mobile release

Pour tester une version Android plus proche production :

```powershell
cd mobile
flutter build apk --release --shrink
```

Le fichier a installer sur le telephone sera genere ici :

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

### Option telephone reel

Par defaut, l'app garde la configuration actuelle pour Chrome et emulateur.
Si un jour tu veux tester l'APK sur un vrai telephone connecte au meme Wi-Fi que ton PC :

```powershell
python run.py --lan
```

Puis reconstruis l'APK en remplacant `192.168.1.25` par l'adresse IP affichee par `run.py` :

```powershell
cd mobile
flutter build apk --release --shrink --dart-define=NOOR_API_BASE_URL=http://192.168.1.25:8000
```

Le lanceur `run.py` genere deja un build web release pour la demo navigateur.
En production backend Linux/macOS, tu peux lancer plusieurs workers avec :

```powershell
$env:NOOR_BACKEND_WORKERS="2"
python run.py
```

En dev Windows, le defaut reste `1` worker pour garder le temps reel en memoire stable.
