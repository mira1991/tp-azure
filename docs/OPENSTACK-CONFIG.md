# Post-configuration OpenStack (state openstack-config)

Root module : `terraform/openstack-config`. Tout ce que le provider
OpenStack supporte proprement est géré ici — Ansible/CLI ne sont utilisés
que pour les opérations de test impératives (smoke tests, workload
d'upgrade) ou non idempotentes.

## Contenu

| Fichier | Ressources |
|---|---|
| `identity.tf` | projet smoke, user technique **sans mot de passe**, rôle observer, assignations (role `member` en data source) |
| `flavors.tf` | flavors `eph.tiny/small/medium` (map extensible) |
| `images.tf` | image CirrOS (URL ou fichier local) |
| `networking.tf` | address scope, subnet pool, réseau externe provider (flat/vlan), sous-réseau externe (pool flottant), réseau + sous-réseau + routeur smoke |
| `security-groups.tf` | secgroup smoke (ICMP + SSH) |
| `storage.tf` | type de volume, quotas compute/blockstorage/network du projet smoke |
| `dns.tf` | zone + recordset Designate (`enable_designate`) |
| `load-balancing.tf` | LB + listener + pool + monitor Octavia (`enable_octavia`), secret Barbican de validation (`enable_barbican`) |

## Authentification

`OS_CLOUD=eph` + `clouds.yaml` temporaire (0600, trap) reconstruit dans
chaque job depuis `passwords.yml` et la VIP interne
(`render-terraform-outputs.py clouds`). Aucun mot de passe OpenStack dans
les variables Terraform ni dans le state — c'est pourquoi l'utilisateur de
test est créé sans mot de passe (les tests s'authentifient en admin).

## Variables notables

- `create_external_network` (défaut true) + `provider_network_type`
  (flat/vlan), `provider_physical_network`, `provider_segmentation_id`,
  `external_cidr/gateway/pool_*` : à aligner avec votre réseau provider
  physique ;
- `test_image_local_path` : image CirrOS locale pour environnements sans
  Internet ;
- `enable_designate` / `enable_octavia` / `enable_barbican` : câblés sur
  `RUN_DESIGNATE_TESTS` / `RUN_OCTAVIA_TESTS` (Barbican : variable
  Terraform explicite).

## Destruction

Ce state est détruit EN PREMIER au teardown (il dépend des API OpenStack).
`check-destroy-plan.py --state openstack-config` valide la liste blanche des
types détruits. Si les API sont déjà mortes : `docs/RECOVERY.md`.
