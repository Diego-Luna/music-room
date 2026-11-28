# VI.3 — Free vs Paid subscription

Le sujet : deux offres (limitée gratuite / illimitée payante), **bascule** entre les deux, et des fonctionnalités (ex. **Music Playlist Editor**) **réservées au payant**.

Pas de Stripe — c’est une démo école. Le switch est `PUT /subscription/me` `{ "tier": "FREE" | "PREMIUM" }`.

## Les deux offres

| | Free | Premium (€9.99/mo, simulé) |
|---|---|---|
| Vote rooms | oui | oui |
| Délégation | oui | oui |
| Rejoindre une playlist | oui | oui |
| **Éditer** tracks (add / move / remove) | selon la licence de la playlist | selon la licence de la playlist |
| **Créer / héberger** une playlist | non | oui |
| Quota de rooms possédées | 3 | illimité |

L'édition n'est pas réservée au Premium : la partie obligatoire (V.2.3) impose « par défaut, tout le monde peut éditer la playlist ». La fonctionnalité payante est donc la **création** d'une playlist (le Music Playlist Editor côté hôte).

Le catalogue est figé dans `backend/src/subscription/subscription.service.ts` (`GET /subscription/plans`).

## Backend

- Prisma `User.subscriptionTier` (`FREE` par défaut).
- `GET /subscription/me`, `PUT /subscription/me`.
- `assertPremium()` → 403 *Creating a playlist requires a premium subscription*.
- Gate : créer une room `PLAYLIST` (`rooms.service`). Add/move/remove items suivent `editAccess` (`playlist.service`).
- Downgrade : les playlists déjà créées **restent** et restent éditables.

## Front

- Settings → **Manage subscription** (sous-titre = plan courant).
- Écran : deux cartes, Current, Upgrade / Switch to Free.
- `SubscriptionProvider` est **global** (login → `refreshTier()`, logout → `clear()`). Le palier est aussi caché dans Hive (`app_settings`) pour qu’un Premium offline voie encore l’éditeur.
- Playlists Free : bouton **Upgrade** à la place de *Create Playlist*. Add / reorder / delete tracks restent disponibles selon la licence de la playlist.

## Démo orale

1. Compte Free → Playlists → Upgrade → écran des offres.
2. Upgrade to Premium → Create Playlist marche.
3. Switch to Free → *Create Playlist* redevient *Upgrade* ; la playlist déjà créée reste là et éditable.

Si on chipote « ce n’est pas un vrai paiement » : le PDF demande la **logique** d’offres et le **switch**, pas un PSP. Stripe est listé dans IV.1 comme techno **écartée**.
