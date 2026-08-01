# Terraform

## Providers épinglés

| Provider | Version | Validé avec | Lock file |
|---|---|---|---|
| e-breuninger/netbox | 3.11.0 | NetBox 4.x (cf. matrice du provider) | `terraform/substrate/.terraform.lock.hcl` |
| bpg/proxmox | 0.66.3 | Proxmox VE 8.x | idem |
| terraform-provider-openstack/openstack | 2.1.0 | OpenStack 2024.1/2024.2 | `terraform/openstack-config/.terraform.lock.hcl` |

Les contraintes sont **exactes** (pas de `>=`). Les lock files sont
versionnés et contiennent les hashes officiels (`zh:` issus des SHA256SUMS
publiés + `h1:` linux_amd64). `make lock` les régénère multi-plateformes.

### Montée de version d'un provider

1. Lire le changelog et la matrice de compatibilité (NetBox surtout :
   les ressources IPAM changent entre versions majeures).
2. Modifier `versions.tf`, exécuter `make lock`, committer les deux fichiers.
3. Dérouler `make lint test` puis une pipeline complète sur un environnement
   jetable AVANT de fusionner.

## Ressources NetBox utilisées

- data : `netbox_site`, `netbox_tenant`, `netbox_cluster`,
  `netbox_vlan_group`, `netbox_vlan`, `netbox_prefixes` (+ `netbox_prefix`
  pour les custom fields), `netbox_vrf`, `netbox_device_role`,
  `netbox_platform`, `netbox_tag` ;
- resources : `netbox_virtual_machine`, `netbox_interface`,
  `netbox_available_ip_address`, `netbox_primary_ip`, `netbox_tag`
  (tags d'environnement/pipeline uniquement).

Limitations connues du provider 3.11.0 :

- pas d'objets MAC séparés (NetBox ≥ 4.2) : la MAC est portée par
  l'attribut `mac_address` de l'interface ;
- `netbox_prefixes` n'expose pas les custom fields (d'où le data source
  singulier complémentaire) ;
- `custom_fields` est une map de chaînes : les types complexes NetBox
  (multi-select…) ne sont pas supportés.

## Backend HTTP GitLab

Entièrement configuré par variables d'environnement (`scripts/terraform-env.sh`) :

```text
TF_HTTP_ADDRESS        ${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/<state>
TF_HTTP_LOCK_ADDRESS   <address>/lock      TF_HTTP_LOCK_METHOD=POST
TF_HTTP_UNLOCK_ADDRESS <address>/lock      TF_HTTP_UNLOCK_METHOD=DELETE
TF_HTTP_RETRY_MAX=6    TF_HTTP_USERNAME=gitlab-ci-token  TF_HTTP_PASSWORD=$CI_JOB_TOKEN
```

Aucun secret de backend dans les `.tf` ni dans les plans. Isolation par
environnement via le nom de state + `resource_group: eph-osk-<id>` sur tous
les jobs mutateurs. Un state détruit reste stocké côté GitLab pour audit —
sa purge éventuelle est une opération d'administration manuelle, jamais
automatisée ici.

## Mode deux phases (compatibilité)

Le mode nominal est un unique `terraform apply` (les providers épinglés
acceptent une IP inconnue au plan). Si une combinaison future de providers
l'empêchait :

1. pipeline avec `TWO_PHASE_APPLY=true` ;
2. job `substrate_allocate` : `apply -var terraform_phase=allocate`
   (VM NetBox + interfaces + IP, zéro VM Proxmox) ;
3. `substrate_apply` : apply complet — les allocations existantes du state
   sont réutilisées telles quelles.

Même state, pas de `-target`, bascule par variable contrôlant le `for_each`
des VM Proxmox.

## Organisation du code

Le root module substrate est découpé par domaine (`data-netbox.tf`,
`netbox-*.tf`, `proxmox-vms.tf`, `cloud-init.tf`, `inventory.tf`…). Les
ressources vivent au niveau racine — choix délibéré : les références
directes entre `netbox_available_ip_address` et les VM Proxmox restent
visibles dans un seul graphe, exactement comme le contrat de teardown
l'exige. La réutilisation passe par les profils YAML (`config/profiles.yml`)
et les locals de transformation, pas par des sous-modules.

## Tests

- `terraform test` (mocks) : `terraform/substrate/tests/topology.tftest.hcl`
  — voir `tests/terraform/README.md` ;
- garde-fou du plan destroy : `scripts/check-destroy-plan.py` (liste blanche
  de types, exécuté sur chaque plan de destruction en pipeline).
