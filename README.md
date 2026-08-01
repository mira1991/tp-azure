# Plateforme OpenStack éphémère — GitLab CI/CD + Terraform + Kolla-Ansible

Création, test, upgrade et destruction **fiable** d'environnements OpenStack
éphémères sur Proxmox, avec un cycle de vie entièrement piloté par Terraform :

- **NetBox** (provider `e-breuninger/netbox`) : recherche des objets réseau
  permanents (data sources), création des VM/interfaces temporaires,
  **réservation dynamique des IP** (`netbox_available_ip_address`) ;
- **Proxmox** (provider `bpg/proxmox`) : clonage, disques, NIC, cloud-init
  alimenté directement par les IP réservées dans NetBox ;
- **OpenStack** (provider officiel) : post-configuration (projets, flavors,
  images, réseaux, quotas...) dans un state séparé ;
- **Kolla-Ansible** : installation/upgrade d'OpenStack via des jobs GitLab
  (jamais dans des provisioners Terraform).

Le teardown repose sur les **states et le graphe de dépendances Terraform** :

```text
create :  VM NetBox -> interfaces -> IP (réservation dynamique) -> VM Proxmox
destroy : VM Proxmox -> IP (libération) -> interfaces -> VM NetBox
```

Une IP n'est jamais libérée avant la destruction de la VM qui la consomme, et
les VLAN/préfixes/sites/tenants permanents (data sources) ne peuvent pas être
supprimés — c'est vérifié sur chaque plan destroy par
`scripts/check-destroy-plan.py`.

## Deux states par environnement

| State | Nom | Contenu |
|---|---|---|
| substrate | `eph-osk-<usage>-<id>-substrate` | data sources NetBox, VM/interfaces/IP NetBox, VM Proxmox, cloud-init, outputs d'inventaire |
| openstack-config | `eph-osk-<usage>-<id>-openstack-config` | projets, users, flavors, images, réseaux, quotas, Designate/Octavia/Barbican |

Ordre de destruction obligatoire : `openstack-config` → `kolla-ansible
destroy` (best effort) → `substrate`.

## Démarrage

1. Lire `docs/PREREQUISITES.md`, `docs/NETBOX.md`, `docs/PROXMOX.md`.
2. Configurer les variables GitLab (`docs/PIPELINE.md`).
3. Construire l'image toolbox : `make toolbox-build toolbox-push`.
4. Lancer une pipeline **web** avec `DEPLOYMENT_PROFILE=minimal`.
5. Approuver `substrate_apply` puis suivre le déploiement.
6. Teardown : jobs `destroy_openstack_config` → `kolla_destroy` →
   `destroy_substrate` (ou `AUTO_TEARDOWN=true`).

## Documentation

| Document | Sujet |
|---|---|
| `docs/ARCHITECTURE.md` | Architecture générale, graphe de dépendances |
| `docs/PREREQUISITES.md` | Prérequis plateforme |
| `docs/TERRAFORM.md` | States, providers épinglés, lock files, modes |
| `docs/NETBOX.md` | Préparation NetBox, custom fields, tags |
| `docs/PROXMOX.md` | Template, storage, nested KVM |
| `docs/KOLLA.md` | Inventaire, globals, passwords |
| `docs/OPENSTACK-CONFIG.md` | Post-configuration Terraform |
| `docs/PIPELINE.md` | Stages, variables, artefacts |
| `docs/UPGRADE.md` | Workflow d'upgrade |
| `docs/TEARDOWN.md` | Teardown nominal et TTL |
| `docs/RECOVERY.md` | Reprise sur incident, import d'orphelins |
| `docs/SECURITY.md` | Gestion des secrets |
| `docs/TROUBLESHOOTING.md` | Pannes connues |
| `docs/RUNBOOK.md` | Opérations au quotidien |

## Développement local

```bash
make lint        # yamllint, ruff, mypy, ansible-lint, tflint, checkov, fmt
make test        # tests unitaires Python + terraform test (mocks)
make lock        # (re)génère les .terraform.lock.hcl multi-plateformes
```
