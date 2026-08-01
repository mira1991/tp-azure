# Troubleshooting

## Terraform / NetBox

| Symptôme | Cause probable | Remède |
|---|---|---|
| `Aucun préfixe actif trouvé pour le VLAN du rôle 'x'` | préfixe absent, non `active`, ou mauvaise VRF | créer/activer le préfixe, vérifier `NETBOX_VRF` |
| `Plusieurs préfixes actifs correspondent…` | doublon de préfixe sur le VLAN | dépréciez l'un des deux dans NetBox |
| `rôle réseau 'x' … n'a pas de VLAN mappé` | variable `NETWORK_ROLE_X` absente | la définir (nom exact du VLAN) |
| erreur provider « no available IPs » à l'allocation | préfixe plein | teardown des environnements expirés ou agrandir le préfixe |
| data source tag `eph` introuvable | tags permanents non créés | `docs/NETBOX.md` |
| 403 NetBox | token sans droits écriture virtualization/ipam | corriger le token |

## Terraform / Proxmox

| Symptôme | Cause probable | Remède |
|---|---|---|
| upload snippet en échec / timeout SSH | pas d'accès SSH du runner aux nœuds, storage sans content-type snippets | `docs/PROXMOX.md` |
| clone bloqué puis timeout | template sur un autre nœud sans storage partagé | renseigner `PROXMOX_TEMPLATE_NODE`, storage partagé ou template répliqué |
| VM sans IP après boot | network-config non pris (image sans cloud-init) ou mauvais bridge/VLAN | vérifier le template, `proxmox_bridge`/`vlan_tag_on_bridge` du rôle |
| `agent … timeout` | qemu-guest-agent absent de l'image | template avec agent (cloud-init l'installe mais il faut un premier boot réseau OK) |
| state lock refusé | autre job en cours sur le même environnement | attendre la fin (resource_group sérialise déjà) ; en cas de crash : GitLab > Terraform states > unlock |

## Kolla

| Symptôme | Remède |
|---|---|
| prechecks : VIP injoignable | la VIP est réservée dans NetBox mais portée par keepalived seulement après deploy — vérifier qu'aucun équipement ne répond déjà sur cette IP |
| deploy : pull d'images en échec | `check_registry_images` doit passer ; vérifier tag/namespace et les credentials registry |
| deploy : mariadb/rabbitmq flapping | RAM insuffisante (profil minimal < 32 Go d'aio) ou horloge non synchronisée (NTP) |
| `validate-kvm` échoue | nested KVM absent : `docs/PROXMOX.md` |
| cinder prechecks : VG manquant | créer `cinder-volumes` sur les nœuds storage ou `RUN_CINDER_TESTS=false` |

## Récupération d'API OpenStack avant teardown

```bash
ssh <control> 'sudo docker ps -a | grep -E "keystone|haproxy|mariadb"'
ssh <control> 'sudo docker restart haproxy keepalived'
# ou depuis le job : kolla-ansible deploy --tags haproxy,keystone -i …
```

Si irrécupérable : procédure openstack-config de `docs/RECOVERY.md`.

## Collecte de diagnostics

```bash
bash scripts/collect-logs.sh substrate-outputs.json artifacts/logs
```

(journal systemd, docker ps, tails /var/log/kolla, ip addr/route par nœud —
automatique en cas d'échec de deploy/upgrade.)
