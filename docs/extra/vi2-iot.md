# VI.2 — IoT / proximité (iBeacon analogue)

Le sujet : *un mécanisme tel qu’iBeacon* — quand on s’approche d’un **event public**, on reçoit **automatiquement** des infos (quoi, comment y accéder, quelle musique).

Pas de BLE réel (web + ordi d’école). L’équivalent = **geofence** : même haversine / rayon que la licence de vote (V.2.1).

## Comportement

1. Un event **public** avec lat/lng/radius (création « location licence »).
2. Position courante = Settings → Vote location (saisie ou « Paris demo »), ou le bouton capteur Events qui **téléporte** dans la zone.
3. `ProximityWatcher` écoute la position **et** la liste d’events, **sur tout l’app** (pas seulement l’onglet Events).
4. Entrer dans la zone → sheet : nom, distance, **music / vibe** (`description`), **how to access** (public / invite-only).
5. Sortir puis revenir → nouvelle alerte. Rester sur place → pas de spam.

## Démo orale

1. Créer un event public avec geo (ex. Paris 48.8566, 2.3522, 500 m).
2. Settings → Vote location → Paris demo **ou** Events → icône capteur.
3. Le sheet s’ouvre tout seul (Home marche aussi une fois les events fetchés).

## Oral si on chipote « ce n’est pas iBeacon »

Le PDF dit *such as*. iBeacon = « je suis près du lieu → push d’infos ». Ici le lieu est un cercle GPS, pas un UUID BLE — même contrat, sans hardware / sans casser le web.
