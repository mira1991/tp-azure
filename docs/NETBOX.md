# NetBox — préparation et conventions

## Objets permanents requis (jamais créés par le projet)

À créer une fois, AVANT la première pipeline :

| Objet | Variable CI | Notes |
|---|---|---|
| Site | `NETBOX_SITE` | nom exact |
| Tenant | `NETBOX_TENANT` | porte toutes les ressources éphémères |
| Cluster de virtualisation | `NETBOX_CLUSTER` | type libre (ex. « Proxmox VE »), idéalement rattaché au site |
| Groupe de VLAN | `NETBOX_VLAN_GROUP` | contient les VLAN des rôles réseau |
| VLAN par rôle réseau | `NETWORK_ROLE_*` | un VLAN nommé par rôle utilisé |
| Préfixe IPv4 **actif** par VLAN | — | exactement UN préfixe actif par VLAN (et par VRF le cas échéant) |
| VRF (optionnel) | `NETBOX_VRF` | vide = table globale |
| Rôle de VM (device role) | `NETBOX_VM_ROLE` | défaut `ephemeral-openstack` |
| Plateforme | `NETBOX_PLATFORM` | défaut `ubuntu-22.04` |
| Tags permanents | — | `eph`, `openstack`, `managed-by-terraform` (cf. `config/netbox-fields.yml`) |

Validation stricte au plan : chaque recherche doit retourner **exactement un
objet** (data sources + postconditions `one()`/`length()`), sinon la
pipeline échoue avec un message explicite (VLAN absent/multiple, préfixe
absent/multiple, VRF incohérente…).

## Custom fields

### Écrits sur les objets éphémères (scope Virtualization > VM)

Type texte, noms mappés dans `config/netbox-fields.yml` (mettre `null` pour
désactiver un champ non provisionné) :

`environment_id`, `environment_name`, `pipeline_id`, `pipeline_url`,
`project_path`, `owner`, `purpose`, `expires_at`, `managed_by`
(valeur : `terraform-gitlab`).

`expires_at` est utilisé par la pipeline planifiée de TTL — il doit exister.

### Lus sur les préfixes permanents (scope IPAM > Prefix, optionnels)

`proxmox_bridge`, `gateway`, `mtu`, `dns_servers`, `search_domain` —
priorité sur `config/network-roles.yml`. Aucun de ces champs n'est
obligatoire : le YAML versionné sert de source par défaut.

## Réservation d'IP

- Ressource unique : `netbox_available_ip_address` (prochaine IP libre du
  préfixe), rattachée à l'interface de VM (`virtual_machine_interface_id`).
- Statut : `NETBOX_EPHEMERAL_IP_STATUS` (défaut `reserved`) pendant toute la
  vie de l'environnement — l'IP est déjà associée à une interface, aucune
  autre pipeline ne peut la prendre. Passer à `active` est possible mais pas
  nécessaire.
- La VIP interne Kolla est réservée dans le préfixe management, sans
  interface.
- L'IP management devient `primary_ip4` de la VM (`netbox_primary_ip`).
- Interdits (et absents du code) : liste des IP libres côté client, choix
  local, `cidrhost()` pour l'allocation, compteur, pool statique.
  (`cidrhost()` n'apparaît que pour dériver l'adresse de la **passerelle**
  permanente, jamais pour allouer.)

## Tags des objets éphémères

`eph`, `openstack`, `managed-by-terraform` (permanents, lus en data source)
+ `environment-<id>` et `pipeline-<id>` (ressources `netbox_tag` du state,
détruites en dernier au teardown).

## Épuisement de préfixe

Si le préfixe n'a plus d'IP libre, l'apply échoue sur la ressource
d'allocation avec l'erreur du provider (HTTP 204/400 NetBox « no available
IPs »). Agrandir le préfixe ou nettoyer les environnements expirés
(`docs/TEARDOWN.md`).
