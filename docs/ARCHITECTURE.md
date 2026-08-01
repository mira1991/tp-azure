# Architecture

## Principe fondamental

Toute ressource ayant un cycle de vie est gérée par Terraform dès lors qu'un
provider fiable existe : NetBox (VM, interfaces, IP éphémères), Proxmox (VM,
disques, NIC, cloud-init) et OpenStack (post-configuration). Kolla-Ansible
reste exécuté par des jobs GitLab car l'installation/upgrade d'OpenStack est
une opération impérative longue qui n'a pas sa place dans des
`local-exec`/`null_resource`.

Les scripts (`scripts/`) sont limités à : validation d'entrées,
transformation d'outputs, attente SSH, tests, collecte de logs, détection
d'orphelins, génération de blocs d'import, reprise exceptionnelle documentée.
Aucun script ne crée ni ne supprime de ressource NetBox/Proxmox dans le
workflow nominal.

## Deux states par environnement

```text
eph-osk-<purpose_short>-<environment_id>-substrate
eph-osk-<purpose_short>-<environment_id>-openstack-config
```

- **substrate** : data sources NetBox permanents + objets éphémères NetBox
  (VM, interfaces, IP, tags d'environnement) + VM Proxmox + snippets
  cloud-init + outputs d'inventaire. NetBox et Proxmox partagent CE state :
  c'est ce qui permet à Terraform de connaître la dépendance IP ↔ VM.
- **openstack-config** : ressources internes à la plateforme OpenStack
  (projets, users, rôles, flavors, images, réseaux, quotas, Designate,
  Octavia, Barbican). Jamais de VM Proxmox ni de réservation NetBox ici.

Le state openstack-config dépend des API OpenStack hébergées par le
substrate : il est donc détruit en premier, tant que les API répondent.

## Graphe de dépendances (substrate)

```text
Objets existants NetBox (data sources)
site / tenant / cluster / vlan_group / VLAN / préfixes / VRF / rôles / tags
                    │
                    ▼
       netbox_virtual_machine.nodes
                    │
                    ▼
        netbox_interface.interfaces
                    │
                    ▼
  netbox_available_ip_address.interfaces   (+ internal_vip)
                    │
        (référence directe .ip_address)
                    ▼
  proxmox_virtual_environment_file.{user_data,network_config}
                    │
                    ▼
     proxmox_virtual_environment_vm.nodes
```

La VM Proxmox consomme `netbox_available_ip_address.interfaces[...].ip_address`
directement (via le network-config cloud-init) : aucun fichier intermédiaire,
aucune recopie. Au destroy, Terraform inverse l'ordre :

```text
VM Proxmox → IP NetBox → interface NetBox → VM NetBox → tags d'environnement
```

L'IP n'est libérée qu'après la VM qui la consomme. Aucun `depends_on`
inversé n'existe (vérifiable dans le code — les seules arêtes sont des
références d'attributs).

## Correspondance déterministe des interfaces

Pour chaque VM, l'ordre des réseaux du profil fixe :

| élément | valeur |
|---|---|
| index NIC Proxmox | position dans `networks` |
| nom Linux | `ethN` (imposé par correspondance MAC dans network-config v1) |
| MAC | `BC:24:11:<env%256>:<ordinal VM>:<index NIC>` |
| interface NetBox | même nom `ethN`, même MAC, VLAN du rôle |
| variable Kolla | host_vars générés (`api_interface`, `tunnel_interface`, ...) |

Rien ne repose sur l'ordre d'énumération du noyau Linux.

## Flux nominal

Voir `docs/PIPELINE.md` pour le détail des stages. Résumé :

```text
validate → preflight → plan/apply substrate → wait SSH → inventaire
→ kolla bootstrap/prechecks/deploy/post-deploy → plan/apply openstack-config
→ tests → (upgrade optionnel) → teardown (3 étapes) → verify_cleanup → close
```

## Limites connues

- Les performances OpenStack en KVM imbriqué ne sont **pas représentatives**
  du bare metal.
- Le provider bpg/proxmox nécessite un accès SSH aux nœuds Proxmox pour
  téléverser les snippets cloud-init (`docs/PROXMOX.md`).
- Les custom fields ne sont pas exposés par le data source pluriel
  `netbox_prefixes` : un data source singulier complémentaire les lit par
  CIDR (`data-netbox.tf`).
- La re-exécution depuis une **nouvelle pipeline** avec le même
  `ENVIRONMENT_ID` conserve VM et IP à l'identique mais met à jour les
  métadonnées de traçabilité (tags/custom fields pipeline_*) — c'est le seul
  écart d'idempotence attendu.
- `kolla-ansible destroy` est best effort : les VM sont de toute façon
  détruites par le substrate.
