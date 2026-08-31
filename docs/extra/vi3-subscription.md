# VI.3 — Free vs Paid subscription

Le sujet : deux offres (limitée gratuite / illimitée payante), **bascule** entre les deux, et des fonctionnalités (ex. **Music Playlist Editor**) **réservées au payant**.

Pas de Stripe — c’est une démo école. Le switch est `PUT /subscription/me` `{ "tier": "FREE" | "PREMIUM" }`.

## Les deux offres

| | Free | Premium (€9.99/mo, simulé) |
|---|---|---|
| Vote rooms | oui | oui |
| Délégation | oui | oui |
| Rejoindre une playlist (invité) | oui | oui |
| **Créer / héberger** une playlist | non | oui |
| **Éditer** tracks (add / move / remove) | non | oui |
| Quota de rooms possédées | 3 | illimité |

Le catalogue est figé dans `backend/src/subscription/subscription.service.ts` (`GET /subscription/plans`).

## Backend

- Prisma `User.subscriptionTier` (`FREE` par défaut).
- `GET /subscription/me`, `PUT /subscription/me`.
- `assertPremium()` → 403 *The Music Playlist Editor requires a premium subscription*.
- Gates : créer une room `PLAYLIST` (`rooms.service`), add/move/remove items (`playlist.service`).
- Downgrade : les playlists déjà créées **restent** ; l’édition tracks est coupée.

## Front

- Settings → **Manage subscription** (sous-titre = plan courant).
- Écran : deux cartes, Current, Upgrade / Switch to Free.
- `SubscriptionProvider` est **global** (login → `refreshTier()`, logout → `clear()`). Le palier est aussi caché dans Hive (`app_settings`) pour qu’un Premium offline voie encore l’éditeur.
- Playlists Free : bouton **Upgrade**, pas de create / add / reorder / delete tracks. Un banner *Playlist editor is Premium*. Join + lecture restent.

## Démo orale

1. Compte Free → Playlists → Upgrade → écran des offres.
2. Upgrade to Premium → Create Playlist marche.
3. Switch to Free → l’éditeur disparaît ; une playlist déjà créée reste visible en lecture.

Si on chipote « ce n’est pas un vrai paiement » : le PDF demande la **logique** d’offres et le **switch**, pas un PSP. Stripe est listé dans IV.1 comme techno **écartée**.
