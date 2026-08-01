# Kolla-Ansible

## Exécution

Les commandes sont lancées depuis l'image toolbox (venvs
`/opt/kolla/source` et `/opt/kolla/target`, sélection `KOLLA_VENV`) :

```text
kolla-ansible bootstrap-servers -i artifacts/inventory/multinode
kolla-ansible prechecks        -i artifacts/inventory/multinode
kolla-ansible deploy           -i artifacts/inventory/multinode
kolla-ansible post-deploy      -i artifacts/inventory/multinode
```

avec `--configdir .kolla --passwords .kolla/passwords.yml`.

## Inventaire

Terraform rend les **groupes d'hôtes** (`kolla_inventory` output) ; le job
`generate_inventory` y concatène les **groupes de services** du fichier
multinode packagé avec la version kolla-ansible installée (à partir de
`[baremetal:children]`) — garantie d'alignement avec la release, sans
maintenir 700 lignes de mapping dans un template.

Groupes :

- `control` = rôles control + aio ; `monitoring` = idem ;
- `network` = nœuds disposant d'une interface **provider** (dans le profil
  `ha` fourni, ce sont les computes — DVR-like ; ajouter `provider` aux
  controls dans `config/profiles.yml` pour un network sur controls) ;
- `compute` = compute + aio ;
- `storage` = storage sinon aio sinon controls ;
- `deployment` = nœud deploy (bastion optionnel, hors groupes Kolla).

Les interfaces par nœud (`network_interface`, `api_interface`,
`tunnel_interface`, `neutron_external_interface`, `storage_interface`) sont
dans les host_vars générés par Terraform — elles peuvent différer d'un rôle
à l'autre.

## globals.yml

`kolla/globals.yml.j2` est rendu par `render-terraform-outputs.py globals`
avec : contexte Terraform (VIP interne réservée dans NetBox, interfaces),
`kolla/versions/source.yml` **ou** `target.yml`, variables de registry, et
les flags `RUN_*_TESTS` (octavia/designate/cinder). Les surcharges de
services vivent dans `kolla/config/`.

## passwords.yml

`KOLLA_PASSWORDS_MODE` :

- `generate` : copie du gabarit de la release + `kolla-genpwd` ;
- `vault` : lecture KV v2 (`KOLLA_VAULT_PASSWORDS_PATH`, clé
  `passwords.yml`) via AppRole.

Toujours : 0600, jamais affiché, artefact à accès restreint (nécessaire pour
conserver les MÊMES secrets entre déploiement source et upgrade — en mode
vault rien n'est artefacté), supprimé du workspace par trap, JAMAIS dans un
state Terraform ni dans les variables Terraform.

## Registry

`KOLLA_REGISTRY`, `KOLLA_REGISTRY_NAMESPACE`, `KOLLA_REGISTRY_USERNAME`,
`KOLLA_REGISTRY_PASSWORD`, `KOLLA_IMAGE_TAG`. Le job
`check_registry_images` vérifie la présence des images cœur au tag demandé
avant tout déploiement.

## Cinder LVM

`RUN_CINDER_TESTS=true` active `enable_cinder_backend_lvm` : le volume group
`cinder-volumes` doit exister sur les nœuds du groupe storage (le playbook
`prepare.yml` avertit s'il manque). Sur le profil minimal, créer le VG dans
le template ou via un disque additionnel.

## Versions

Épinglées dans `kolla/versions/source.yml` / `target.yml`
(`openstack_release`, `kolla_ansible_version`, `ansible_core_version`,
`kolla_image_tag`, `kolla_base_distro`) et reflétées dans les ARG du
`ci/Dockerfile`. Jamais d'installation de « dernière version ». Vérifier
les tags d'images sur votre miroir avant de changer ces fichiers.
