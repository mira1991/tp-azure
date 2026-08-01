# Upgrade OpenStack (RUN_UPGRADE=true)

## Principe

Bascule `kolla/versions/source.yml` → `kolla/versions/target.yml` sur le
MÊME substrate (les VM Proxmox ne sont jamais recréées) avec le MÊME
`passwords.yml`. L'image toolbox embarque les deux versions de
kolla-ansible (venvs `source`/`target`, sélection `KOLLA_VENV`).

## Déroulé (stage upgrade, ordonné par needs)

1. `upgrade_gate` — approbation **manuelle** obligatoire.
2. `pre_upgrade_workload` — smoke tests avant upgrade (JUnit
   `pre-upgrade.xml`) puis création d'une VM témoin + volume attaché qui
   doivent survivre à l'upgrade ; snapshot des services
   (`services-before.json`).
3. `kolla_upgrade_prechecks` — re-rend `globals.yml` avec `target.yml`
   (même passwords, même inventaire) puis `kolla-ansible prechecks` en venv
   target.
4. `kolla_upgrade` — `kolla-ansible upgrade` (timeout 4 h ; logs collectés
   en cas d'échec).
5. `post_upgrade_verify` — services identiques (aucun service perdu), VM
   témoin toujours `ACTIVE`, smoke tests rejoués (JUnit
   `post-upgrade.xml`), rapport `artifacts/upgrade/upgrade-report.json`
   (avant/après), puis nettoyage du témoin.

## Procédure

1. Lancer une pipeline web avec `RUN_UPGRADE=true` (profil `ha`
   recommandé) ; dérouler le déploiement source + tests.
2. Jouer `upgrade_gate` après validation humaine des tests source.
3. Suivre les jobs 2→5 ; en cas d'échec de `kolla_upgrade`, voir
   `docs/TROUBLESHOOTING.md` (l'environnement est conservé pour analyse —
   ne PAS toucher aux ressources Terraform).
4. Teardown normal ensuite (`docs/TEARDOWN.md`).

## Changer les versions

Éditer `kolla/versions/source.yml` et `target.yml` (release, version
kolla-ansible, ansible-core, tag d'images), aligner les ARG du
`ci/Dockerfile`, reconstruire/pousser l'image toolbox avec un nouveau tag,
mettre à jour `TOOLBOX_IMAGE`. Le job `check_registry_images` doit passer
sur les deux tags avant usage.
