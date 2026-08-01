# Pipeline GitLab CI/CD

## Stages

```text
validate → preflight → substrate_plan → substrate_apply → wait → inventory
→ bootstrap → kolla_prechecks → kolla_deploy
→ openstack_config_plan → openstack_config_apply → test → upgrade → publish
→ destroy_openstack_config → kolla_destroy → destroy_substrate
→ verify_cleanup → close
```

## Types de pipelines

| Déclencheur | Comportement |
|---|---|
| Merge request | validation seule (`DEPLOY_FROM_MERGE_REQUEST=true` pour déployer) |
| Push branche par défaut | validation seule |
| Web / trigger / API | cycle complet ; `substrate_apply` et `openstack_config_apply` manuels sauf `AUTO_APPLY=true` |
| Schedule + `REAPER=true` | détection TTL → déclenche des pipelines `TEARDOWN_ONLY=true` |
| Trigger + `TEARDOWN_ONLY=true` | teardown d'un environnement existant (`ENVIRONMENT_ID` + `PURPOSE_SHORT`) |

Concurrence : chaque pipeline a son `ENVIRONMENT_ID` (défaut
`CI_PIPELINE_IID`) donc ses propres states et IP ; le
`resource_group eph-osk-<id>` sérialise les mutations d'un même
environnement. Une relance avec le même `ENVIRONMENT_ID` réutilise le state,
les IP et les VM (plan idempotent, aucune nouvelle réservation).

## Variables fonctionnelles

Colonnes : type / défaut / obligatoire / sensible / consommée par.

| Variable | Type | Défaut | Oblig. | Sens. | Jobs |
|---|---|---|---|---|---|
| ENVIRONMENT_ID | entier | `CI_PIPELINE_IID` | non | non | tous |
| ENVIRONMENT_NAME | dérivée | `eph-osk-<purpose>-<id>` | — | non | tous |
| ENVIRONMENT_OWNER | string | `GITLAB_USER_LOGIN` | non | non | substrate |
| ENVIRONMENT_PURPOSE | string | `ephemeral-openstack` | non | non | substrate |
| PURPOSE_SHORT | string `[a-z0-9]{2,8}` | `dev` | non | non | tous |
| ENVIRONMENT_TTL_HOURS | entier | `48` | non | non | resolve, substrate |
| DEPLOYMENT_PROFILE | `minimal\|ha` | `minimal` | non | non | substrate |
| PLACEMENT_STRATEGY | `spread\|pack\|manual` | `spread` | non | non | substrate |
| TERRAFORM_PHASE | `full\|allocate` | `full` | non | non | substrate |
| TWO_PHASE_APPLY | bool | `false` | non | non | substrate |
| PROXMOX_API_URL | URL | — | oui | non | preflight, substrate, tests |
| PROXMOX_TOKEN_ID / _SECRET | string | — | oui | **oui** | idem |
| PROXMOX_INSECURE | bool | `false` | non | non | idem |
| PROXMOX_TARGET_NODES | CSV | — | oui | non | substrate |
| PROXMOX_POOL | string | vide | non | non | substrate |
| PROXMOX_TEMPLATE | VMID | — | oui | non | substrate |
| PROXMOX_TEMPLATE_NODE | string | vide | non | non | substrate |
| PROXMOX_STORAGE | string | — | oui | non | substrate |
| PROXMOX_SNIPPETS_STORAGE | string | `local` | non | non | substrate |
| PROXMOX_SSH_USERNAME | string | `root` | non | non | substrate |
| PROXMOX_SSH_PRIVATE_KEY | PEM | = SSH_PRIVATE_KEY | non | **oui** | substrate |
| NETBOX_URL | URL | — | oui | non | preflight, substrate, tests, reaper |
| NETBOX_TOKEN | string | — | oui | **oui** | idem |
| NETBOX_SITE / NETBOX_TENANT / NETBOX_CLUSTER / NETBOX_VLAN_GROUP | string | — | oui | non | substrate |
| NETBOX_VRF | string | vide | non | non | substrate |
| NETBOX_VM_ROLE | string | `ephemeral-openstack` | non | non | substrate |
| NETBOX_PLATFORM | string | `ubuntu-22.04` | non | non | substrate |
| NETBOX_EPHEMERAL_IP_STATUS | `reserved\|active` | `reserved` | non | non | substrate, test_netbox |
| NETWORK_ROLE_MANAGEMENT | nom VLAN | — | oui | non | substrate |
| NETWORK_ROLE_INTERNAL_API / _TUNNEL / _PROVIDER / _STORAGE / _OCTAVIA_MANAGEMENT | nom VLAN | vide | selon profil | non | substrate |
| SSH_PRIVATE_KEY | PEM | — | oui | **oui** | wait, kolla, tests, teardown |
| SSH_PUBLIC_KEY | string | — | oui | non | substrate |
| SSH_KNOWN_HOSTS | string | vide | non | non | jobs SSH |
| NODE_SSH_USERNAME | string | `kolla` | non | non | substrate, kolla |
| KOLLA_REGISTRY / KOLLA_REGISTRY_NAMESPACE | string | — / `kolla` | oui / non | non | preflight, kolla |
| KOLLA_REGISTRY_USERNAME / _PASSWORD | string | vide | non | **oui** | preflight, kolla |
| KOLLA_IMAGE_TAG | string | — | oui | non | preflight (les tags de déploiement viennent de kolla/versions/*.yml) |
| KOLLA_PASSWORDS_MODE | `generate\|vault` | `generate` | non | non | kolla_generate_config |
| VAULT_ADDR / VAULT_ROLE_ID / VAULT_SECRET_ID / KOLLA_VAULT_PASSWORDS_PATH | string | — | si vault | **oui** | kolla_generate_config |
| TF_HTTP_ADDRESS / _LOCK_ADDRESS / _UNLOCK_ADDRESS / _USERNAME / _PASSWORD | string | dérivés job token | non | **oui** | jobs terraform (override) |
| OPENSTACK_SOURCE_VERSION / OPENSTACK_TARGET_VERSION / KOLLA_ANSIBLE_VERSION / ANSIBLE_CORE_VERSION | doc | kolla/versions/*.yml | — | non | référence (les valeurs effectives sont versionnées) |
| RUN_UPGRADE | bool | `false` | non | non | stage upgrade |
| RUN_OCTAVIA_TESTS / RUN_DESIGNATE_TESTS / RUN_CINDER_TESTS / RUN_LIVE_MIGRATION_TESTS | bool | `false/false/true/false` | non | non | kolla config, osc, tests |
| AUTO_APPLY / AUTO_DEPLOY / AUTO_TEARDOWN | bool | `false` | non | non | gates |
| DEPLOY_FROM_MERGE_REQUEST | bool | `false` | non | non | rules |
| TEARDOWN_ONLY / REAPER | bool | `false` | non | non | rules |
| FORCE_CLEANUP_CONFIRMATION | string | vide | break-glass | non | RECOVERY |

Les variables sensibles doivent être **masked** (+ **protected** si vos
pipelines tournent sur refs protégées) et limitées aux environnements/jobs
nécessaires.

## Artefacts

Conservés : plans substrate/openstack (accès `developer`), outputs filtrés,
inventaire + host_vars, manifeste d'environnement, logs Kolla (échec),
résultats prechecks, JUnit (unit/netbox/proxmox/openstack/upgrade), rapport
avant/après upgrade, rapports de teardown/destroy-plan, rapport d'orphelins.

Jamais publiés : state Terraform en artefact public, tokens, clé privée
SSH, `passwords.yml` en accès public (artefact restreint `developer`,
expiration 7 j, ou mode vault), `clouds.yaml` (jamais artefacté),
credentials de registry.

## Environnement GitLab et TTL

`substrate_apply` crée l'environnement dynamique
`eph/openstack/<ENVIRONMENT_NAME>` (`on_stop: close_environment`).
`created_at`/`expires_at` sont calculés une fois (job `resolve_environment`)
et propagés : custom fields NetBox, tags NetBox/Proxmox, descriptions,
outputs, manifeste. Une pipeline **planifiée** avec `REAPER=true` détecte
les environnements expirés dans NetBox (lecture seule) et déclenche pour
chacun une pipeline `TEARDOWN_ONLY=true AUTO_TEARDOWN=true` — la
suppression passe toujours par Terraform.

Pour créer la schedule : GitLab > CI/CD > Schedules, cron souhaité,
variables `REAPER=true`.
