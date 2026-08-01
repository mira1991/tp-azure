# Prérequis

## GitLab

- GitLab ≥ 16.11 (artefacts `access: developer`, backend HTTP Terraform,
  environnements dynamiques, `resource_group`).
- Un runner Docker capable d'atteindre : l'API NetBox, l'API Proxmox
  (+ SSH vers les nœuds Proxmox), le VLAN management des VM éphémères
  (directement ou via le bastion deploy, `ssh_via_deploy_bastion`),
  la registry d'images Kolla.
- La registry de conteneurs du projet activée (image toolbox).

## NetBox

- Version 4.x recommandée (provider épinglé `e-breuninger/netbox 3.11.0` —
  vérifier la matrice de compatibilité du provider avant toute montée de
  version, `docs/NETBOX.md`).
- Un token API avec droits lecture + écriture sur virtualization/ipam/extras.
- Les objets permanents décrits dans `docs/NETBOX.md` (site, tenant,
  cluster, groupe de VLAN, VLAN + préfixes actifs par rôle réseau, rôle de
  VM, plateforme, tags permanents, custom fields).

## Proxmox VE

- Proxmox VE 8.x (provider épinglé `bpg/proxmox 0.66.3`).
- Un token API (voir permissions dans `docs/PROXMOX.md`).
- Un accès SSH aux nœuds (upload des snippets cloud-init).
- Un template cloud-init Ubuntu 22.04 avec qemu-guest-agent
  (`docs/PROXMOX.md`).
- Un datastore acceptant le content-type `snippets`.
- Nested virtualization activée sur les hyperviseurs
  (`kvm-intel nested=1` / `kvm-amd nested=1`).

## Registry d'images Kolla

- Miroir des images `kolla` pour les tags `2024.1-ubuntu-jammy` (source) et
  `2024.2-ubuntu-jammy` (cible) — ou les tags que vous épinglez dans
  `kolla/versions/*.yml`. Le job `check_registry_images` valide la présence
  des images cœur avant tout déploiement.

## Dimensionnement indicatif

| Profil | vCPU | RAM | Disque |
|---|---|---|---|
| minimal | 14 | 36 Go | 190 Go |
| ha (sans storage) | 51 | 116 Go | 640 Go |
| ha (avec storage) | 59 | 132 Go | 940 Go |

## Vault (optionnel)

`KOLLA_PASSWORDS_MODE=vault` requiert un Vault accessible avec auth AppRole
et un secret KV contenant la clé `passwords.yml`
(`KOLLA_VAULT_PASSWORDS_PATH`, format v2 : `secret/data/...`).
