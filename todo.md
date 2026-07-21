# À faire (mandatory restant)

Sur `main` actuel — gaps pour viser « mandatory perfect ».

1. ~~**URL backend configurable dans l’app** (V.5)~~ ✅  
   Champ Login + Settings, persisté (Hive), appliqué à API + Socket.

2. ~~**Logs Platform / Device / Version** (V.6)~~ ✅  
   - `x-device` = modèle lisible (iPhone 15, Pixel 7, Chrome…)  
   - `x-device-id` = UUID stable (sessions / délégation)  
   - Mêmes tags sur WebSocket (headers natifs + `auth` sur web)

3. ~~**Loadtest playlist vert** (V.7)~~ ✅  
   Script `03_playlist_reorder` : upgrade PREMIUM + `editAccess: EVERYONE`.  
   Résultat : `backend/loadtest/results/03_playlist_reorder.txt` (0% fail, p95 ~41ms).

4. ~~**Vote geo côté app** (V.2.1)~~ ✅  
   Settings → Vote location (lat/lng) ; envoyés sur chaque vote. Room parse `voteLocation*`.

5. **OAuth natif (si démo téléphone)** (V.5)  
   Remplir secrets locaux (`Secrets.xcconfig`, `local.properties`, éventuellement `google-services.json`). Sur web / ordi d’école : moins prioritaire.

---

**Bonus**  
- ~~VI.2 IoT / iBeacon~~ ✅ géofence client + bouton Events « Enter proximity zone »  
  → snackbar + sheet (nom, vibe, comment accéder). Pas de BLE réel.

**Note locale à remettre** : CORS `https://localhost:8443` → voir `note-cors-8443.md`
