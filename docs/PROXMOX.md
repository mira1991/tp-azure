# Proxmox — préparation

## Token API

Créer un utilisateur + token dédiés, par exemple :

```bash
pveum user add eph-terraform@pve
pveum aclmod / -user eph-terraform@pve -role PVEVMAdmin
pveum aclmod /storage -user eph-terraform@pve -role PVEDatastoreUser
pveum user token add eph-terraform@pve gitlab --privsep 0
```

Variables CI : `PROXMOX_API_URL` (ex. `https://pve:8006/api2/json`),
`PROXMOX_TOKEN_ID` (`eph-terraform@pve!gitlab`), `PROXMOX_TOKEN_SECRET`,
`PROXMOX_INSECURE` (`true` uniquement en lab avec certificat auto-signé).

## Accès SSH aux nœuds (snippets)

Le provider bpg téléverse les snippets cloud-init (user-data /
network-config) via SSH. Fournir une clé (`PROXMOX_SSH_PRIVATE_KEY`, sinon
`SSH_PRIVATE_KEY`) chargée en ssh-agent par les jobs, et
`PROXMOX_SSH_USERNAME` (défaut `root`). Le datastore
`PROXMOX_SNIPPETS_STORAGE` (défaut `local`) doit accepter le content-type
`snippets`.

## Template cloud-init

Template Ubuntu 22.04 minimal (exemple, à adapter) :

```bash
qm create 9000 --name tpl-ubuntu-2204 --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single --serial0 socket
qm set 9000 --scsi0 local-lvm:0,import-from=/root/jammy-server-cloudimg-amd64.img
qm set 9000 --ide2 local-lvm:cloudinit --boot order=scsi0 --agent enabled=1
qm template 9000
```

Exigences : image cloud (cloud-init fonctionnel), qemu-guest-agent installé
ou installable (cloud-init du projet l'installe et l'active), console série.
Variables : `PROXMOX_TEMPLATE` (VMID), `PROXMOX_TEMPLATE_NODE` (si le
template ne vit que sur un nœud).

## Virtualisation imbriquée

Sur chaque hyperviseur :

```bash
echo "options kvm-intel nested=1" > /etc/modprobe.d/kvm-intel.conf   # Intel
echo "options kvm-amd nested=1"  > /etc/modprobe.d/kvm-amd.conf      # AMD
```

Les VM compute/aio reçoivent `cpu type = host` (proxmox-vms.tf). La
pipeline vérifie ensuite sur chaque compute : `/dev/kvm`, `lsmod | grep
kvm`, `egrep -c '(vmx|svm)' /proc/cpuinfo`
(`ansible/playbooks/validate-kvm.yml` + `tests/integration/test_proxmox.py`)
et échoue avec un message explicite sinon. Les performances en KVM imbriqué
ne sont pas représentatives du bare metal.

## Réseau

Chaque rôle réseau est raccordé à un bridge (custom field NetBox
`proxmox_bridge` ou `config/network-roles.yml`) :

- bridge **trunk** (`vlan_tag_on_bridge: true`, défaut) : Terraform pose le
  tag VLAN du rôle sur la NIC ;
- bridge **dédié** au VLAN (`vlan_tag_on_bridge: false`) : pas de tag.

Le MTU par rôle est appliqué sur la NIC Proxmox et dans le network-config
cloud-init.

## Placement

`PLACEMENT_STRATEGY` : `spread` (round-robin par rôle sur
`PROXMOX_TARGET_NODES` — les 3 control planes ne partagent jamais le même
hyperviseur dès 2 nœuds), `pack` (tout sur le premier nœud), `manual`
(mapping `placement_manual` par nom de VM ou par rôle). Le calcul est
déterministe (testé dans `topology.tftest.hcl`).

## Tags et VMID

Tags posés sur chaque VM : `eph`, `openstack`, `managed_by_terraform`,
`environment_<id>`, `pipeline_<id>`, `expires_<yyyy_mm_dd>` (normalisés
`[a-z0-9_.-]`). `PROXMOX_VMID_BASE` (optionnel) fixe des VMID déterministes
`base + ordinal`.
