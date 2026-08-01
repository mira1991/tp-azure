# Teardown

## Ordre obligatoire

```text
terraform destroy openstack-config      (destroy_openstack_config, allow_failure)
              │
              ▼
kolla-ansible destroy                    (kolla_destroy, best effort)
              │
              ▼
terraform plan -destroy substrate
   + contrôle check-destroy-plan.py
              │
              ▼
terraform destroy substrate              (destroy_substrate, allow_failure: false)
   ├── destruction des VM Proxmox
   ├── libération des IP NetBox        (APRÈS leurs VM consommatrices)
   ├── suppression des interfaces NetBox
   ├── suppression des VM NetBox
   └── suppression des tags d'environnement
              │
              ▼
verify_cleanup                           (aucun objet taggé restant)
              │
              ▼
close_environment                        (environnement GitLab stoppé)
```

Ne JAMAIS supprimer les VM Proxmox avant d'avoir détruit le state
openstack-config : ses ressources deviendraient injoignables.

## Garanties

- L'ordre VM → IP → interface → VM NetBox est porté par le graphe de
  dépendances (références directes d'attributs), pas par de l'outillage :
  un échec partiel laisse un state exact et un destroy relançable.
- `scripts/check-destroy-plan.py` bloque l'apply si le plan destroy contient
  un type hors liste blanche (VLAN, préfixe, site, tenant… → impossible par
  construction puisqu'ils sont des data sources, et vérifié quand même).
- Les VLAN et préfixes permanents ne sont jamais touchés.
- `destroy_substrate` est **manuel avec `allow_failure: false`** et ne
  dépend que de `resolve_environment` : il reste exécutable même si Kolla,
  les prechecks, les tests, `kolla-ansible destroy` ont échoué ou si le
  state openstack-config est vide.

## Modes

- **Manuel** (défaut) : jouer les 3 jobs dans l'ordre depuis la pipeline de
  création (ou n'importe quelle pipeline `TEARDOWN_ONLY=true` du même
  environnement).
- **Automatique** : `AUTO_TEARDOWN=true` — les jobs s'enchaînent
  (`when: always`, donc même après un échec en amont).
- **TTL** : pipeline planifiée `REAPER=true` → déclenche
  `TEARDOWN_ONLY=true AUTO_TEARDOWN=true` par environnement expiré
  (`expires_at` NetBox).

## Teardown d'un environnement depuis une autre pipeline

Lancer une pipeline (web/trigger) avec :

```text
TEARDOWN_ONLY=true
ENVIRONMENT_ID=<id>        PURPOSE_SHORT=<purpose>     # reconstitue le nom de state
AUTO_TEARDOWN=true         # ou jouer les jobs manuellement
```

## Après teardown

- `verify_cleanup` échoue (code 2) s'il reste des objets taggés → suivre
  `docs/RECOVERY.md`.
- Le state (vide) est conservé côté GitLab pour audit pendant la durée de
  rétention de votre instance ; sa suppression éventuelle est une décision
  d'administration manuelle, jamais avant validation complète du teardown.
- Rapports produits : plans destroy JSON, state final, rapport d'orphelins,
  logs.
