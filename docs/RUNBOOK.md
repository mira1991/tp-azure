# Runbook opérateur

## Créer un environnement

1. CI/CD > Pipelines > **Run pipeline** (branche par défaut).
2. Renseigner au minimum : `DEPLOYMENT_PROFILE`, `PURPOSE_SHORT`,
   éventuellement `ENVIRONMENT_TTL_HOURS`, `RUN_*_TESTS`.
3. La pipeline valide, résout l'environnement, plane le substrate.
4. **Relire `substrate-plan.txt`** (artefact) puis jouer `substrate_apply`.
5. Suivre wait → inventory → bootstrap → prechecks → deploy (≈ 45–90 min).
6. Jouer `openstack_config_apply` après lecture du plan.
7. Vérifier les JUnit du stage test.

Accès à la plateforme : VIP interne dans le manifeste
(`artifacts/environment-manifest.json`), credentials admin via
`passwords.yml` (artefact restreint) — `render-terraform-outputs.py clouds`
reconstruit un clouds.yaml local.

## Relancer sur un environnement existant

Run pipeline avec `ENVIRONMENT_ID=<id>` et `PURPOSE_SHORT=<purpose>` de
l'environnement : mêmes states, mêmes IP, mêmes VM ; le plan doit être
vide/métadonnées seulement. Toute autre différence = dérive à investiguer
avant apply.

## Upgrade

`RUN_UPGRADE=true` (profil `ha` recommandé) puis suivre `docs/UPGRADE.md`.

## Détruire

Jobs `destroy_openstack_config` → `kolla_destroy` → `destroy_substrate`
dans la pipeline de l'environnement (ou pipeline `TEARDOWN_ONLY=true`
ciblée). Détail et garanties : `docs/TEARDOWN.md`.

## Incidents fréquents

- Pipeline rouge sur `verify_cleanup` → `docs/RECOVERY.md` (réconciliation).
- Destroy substrate rouge → `retry_substrate_destroy` après correction.
- Environnement gelé/expiré → attendre la reaper planifiée ou lancer le
  teardown ciblé.

## Contrôles manuels avant première utilisation

1. `make lint test` en local : tout vert.
2. Variables GitLab créées (liste `docs/PIPELINE.md`), sensibles masked.
3. Objets NetBox permanents présents (`docs/NETBOX.md`) — y compris tags et
   custom fields.
4. Template Proxmox conforme + nested KVM activé (`docs/PROXMOX.md`).
5. Image toolbox construite et poussée (`make toolbox-build toolbox-push`),
   `TOOLBOX_IMAGE` à jour.
6. `check_registry_images` vert sur les tags source ET target.
7. Un cycle complet `minimal` avec teardown (verify_cleanup vert) AVANT le
   premier `ha`.
8. Schedule reaper créée (`REAPER=true`).
