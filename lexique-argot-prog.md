# Lexique — jargon / argot prog

Petits mots qu’on utilise souvent en dev / review / CI. Pas du français « correct », mais du parler d’équipe.

| Terme | Sens |
|---|---|
| **flaky** | Test (ou outil) **instable** : parfois vert, parfois rouge, sans vrai bug dans le code. Ex. : automation UI qui rate un clic au hasard. |
| **flake** | Un run flaky. « On a un flake sur CI » = un test a échoué pour une raison non fiable. |
| **retarget** | Pointer ailleurs (ex. changer l’URL du backend pour que les requêtes aillent vers un autre serveur). |
| **live test** | Test qui parle à un **vrai** service qui tourne (ex. Nest sur `:3000`), pas un mock. |
| **mock** | Faux objet / fausse réponse pour tester sans le vrai système. |
| **E2E** | *End-to-end* : test du parcours complet (UI → API → DB), pas juste une fonction isolée. |
| **unit test** | Test d’une petite unité (fonction / classe) isolée. |
| **smoke test** | Test rapide « ça démarre / le chemin critique marche » — pas exhaustif. |
| **WIP** | *Work in progress* — pas prêt à merger. |
| **LGTM** | *Looks good to me* — OK pour merge (review). |
| **nit** | Remarque mineure en review (style, typo), pas bloquante. |
| **blocker** | Problème qui **bloque** le merge / la livraison. |
| **hotfix** | Correctif urgent en prod / sur main. |
| **regression** | Un truc qui **marchait** et qui est cassé après un changement. |
| **edge case** | Cas limite / rare (entrée vide, timeout, double clic…). |
| **happy path** | Le scénario nominal où tout se passe bien. |
| **stub** | Version minimale d’une dépendance (proche du mock). |
| **fixture** | Données / état de départ pour un test. |
| **seed** | Remplir la DB avec des données de démo / test. |
| **hydrate** | Remplir un objet / le store avec des données (souvent depuis l’API). |
| **bootstrap** | Démarrer / initialiser l’app ou un module. |
| **wiring** | Brancher les dépendances entre elles (DI, providers…). |
| **plumbing** | Code d’infra / tuyauterie (pas la feature métier). |
| **spaghetti** | Code embroussaillé, difficile à suivre. |
| **tech debt** | Dette technique — raccourcis à rembourser plus tard. |
| **YAGNI** | *You Aren’t Gonna Need It* — ne pas coder « au cas où ». |
| **DRY** | *Don’t Repeat Yourself* — éviter la duplication inutile. |
| **ship** | Livrer / mettre en prod / merger pour que ce soit utilisable. |
| **green / red** | CI ou tests : vert = OK, rouge = échec. |
| **timeout** | Délai dépassé → échec (réseau, test trop lent…). |
| **race** | *Race condition* : bug lié à l’ordre / timing de deux actions concurrentes. |
| **heisenbug** | Bug qui disparaît quand on essaie de le debugger. |
| **bitrot** | Code / docs qui pourrissent faute d’entretien. |
| **bike-shedding** | Débattre longtemps d’un détail sans importance. |
| **yak shaving** | Enchaîner des tâches annexes avant de pouvoir faire la vraie tâche. |
| **rubber duck** | Expliquer le bug à voix haute (même à un canard) pour le trouver. |
| **spike** | Exploration courte pour apprendre / prototyper, pas du code final. |
| **MVP** | *Minimum Viable Product* — version minimale utile. |
| **a11y** | *Accessibility* (11 lettres entre a et y). |
| **i18n** | *Internationalization*. |
| **l10n** | *Localization*. |

À enrichir au fil des reviews / soutenances.
