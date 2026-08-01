# Tests unitaires de la transformation de topologie (terraform test, providers
# mockés : aucun accès NetBox/Proxmox requis).
#
# Vérifie : génération des noms, unicité des clés for_each, nombre
# d'interfaces et d'allocations IP, absence d'IP sur le réseau provider,
# placement spread déterministe, et mode deux phases (allocate/full).

mock_provider "netbox" {
  mock_data "netbox_site" {
    defaults = { id = "1" }
  }
  mock_data "netbox_tenant" {
    defaults = { id = "2" }
  }
  mock_data "netbox_cluster" {
    defaults = { id = "3" }
  }
  mock_data "netbox_vlan_group" {
    defaults = { id = "4" }
  }
  mock_data "netbox_device_role" {
    defaults = { id = "5" }
  }
  mock_data "netbox_platform" {
    defaults = { id = "6" }
  }
  mock_data "netbox_tag" {
    defaults = { id = "7" }
  }
  mock_data "netbox_vrf" {
    defaults = { id = "8" }
  }
  mock_data "netbox_vlan" {
    defaults = { id = "20" }
  }
  # Liste calculée -> mockable (contrairement à l'attribut optionnel `prefix`
  # du data source singulier). Exactement un préfixe : les postconditions
  # d'unicité passent.
  mock_data "netbox_prefixes" {
    defaults = {
      prefixes = [{
        id          = 10
        prefix      = "192.0.2.0/24"
        description = "mock"
        tenant_id   = 2
        site_id     = 1
        vlan_vid    = 100
        vlan_id     = 20
        vrf_id      = 0
        status      = "active"
        tags        = []
      }]
    }
  }
}

mock_provider "proxmox" {}

variables {
  environment_id        = 142
  purpose_short         = "upg"
  environment_owner     = "ci"
  environment_purpose   = "unit-test"
  expires_at            = "2026-01-01T00:00:00Z"
  created_at            = "2025-12-30T00:00:00Z"
  pipeline_id           = "9999"
  ssh_public_key        = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH1unittestkeyunittestkeyunittestkeyunittest"
  proxmox_target_nodes  = ["pve-01", "pve-02"]
  proxmox_template_vmid = 9000
  proxmox_storage       = "local-lvm"
  netbox_site           = "site"
  netbox_tenant         = "tenant"
  netbox_cluster        = "cluster"
  netbox_vlan_group     = "vlans"
  network_role_vlans = {
    management   = "vlan-mgmt"
    internal_api = "vlan-api"
    tunnel       = "vlan-tun"
    provider     = "vlan-prov"
    storage      = "vlan-sto"
  }
}

run "minimal_topology" {
  command = plan

  variables {
    deployment_profile = "minimal"
  }

  assert {
    condition     = length(netbox_virtual_machine.nodes) == 2
    error_message = "Le profil minimal doit produire 2 VM (deploy + aio)."
  }

  assert {
    condition     = length(netbox_interface.interfaces) == 5
    error_message = "Le profil minimal doit produire 5 interfaces (1 deploy + 4 aio)."
  }

  assert {
    condition     = length(netbox_available_ip_address.interfaces) == 4
    error_message = "Le profil minimal doit réserver 4 IP (provider = L2 pur, sans IP)."
  }

  assert {
    condition     = !contains(keys(netbox_available_ip_address.interfaces), "eph-osk-upg-142-aio-01/provider")
    error_message = "Aucune IP ne doit être allouée sur le réseau provider."
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.nodes) == 2
    error_message = "Le profil minimal doit produire 2 VM Proxmox en phase full."
  }

  assert {
    condition = alltrue([
      for name in keys(netbox_virtual_machine.nodes) :
      can(regex("^eph-osk-upg-142-(deploy|aio|cpl|cpt|sto)-[0-9]{2}$", name))
    ])
    error_message = "Convention de nommage eph-osk-<usage>-<env>-<rôle>-<index> non respectée."
  }

  assert {
    condition     = contains(keys(netbox_virtual_machine.nodes), "eph-osk-upg-142-deploy-01") && contains(keys(netbox_virtual_machine.nodes), "eph-osk-upg-142-aio-01")
    error_message = "Noms attendus : eph-osk-upg-142-deploy-01 et eph-osk-upg-142-aio-01."
  }
}

run "ha_topology" {
  command = plan

  variables {
    deployment_profile = "ha"
  }

  assert {
    condition     = length(netbox_virtual_machine.nodes) == 6
    error_message = "Le profil ha doit produire 6 VM (1 deploy + 3 control + 2 compute, storage désactivé)."
  }

  assert {
    condition     = length(netbox_interface.interfaces) == 16
    error_message = "Le profil ha doit produire 16 interfaces (1 + 3x3 + 2x3)."
  }

  assert {
    condition     = length(netbox_available_ip_address.interfaces) == 14
    error_message = "Le profil ha doit réserver 14 IP (les interfaces provider des computes n'en reçoivent pas)."
  }

  assert {
    condition     = length(keys(netbox_available_ip_address.interfaces)) == length(distinct(keys(netbox_available_ip_address.interfaces)))
    error_message = "Les clés for_each des allocations IP doivent être uniques."
  }

  # spread : les control planes sont répartis sur les nœuds Proxmox.
  assert {
    condition = (
      proxmox_virtual_environment_vm.nodes["eph-osk-upg-142-cpl-01"].node_name
      != proxmox_virtual_environment_vm.nodes["eph-osk-upg-142-cpl-02"].node_name
    )
    error_message = "placement spread : cpl-01 et cpl-02 ne doivent pas partager le même hyperviseur."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.nodes["eph-osk-upg-142-cpl-01"].node_name == proxmox_virtual_environment_vm.nodes["eph-osk-upg-142-cpl-03"].node_name
    error_message = "placement spread déterministe : cpl-03 revient sur le premier nœud (round-robin sur 2 nœuds)."
  }
}

run "allocate_phase_keeps_proxmox_empty" {
  command = plan

  variables {
    deployment_profile = "minimal"
    terraform_phase    = "allocate"
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.nodes) == 0
    error_message = "En phase allocate, aucune VM Proxmox ne doit être planifiée."
  }

  assert {
    condition     = length(netbox_available_ip_address.interfaces) == 4
    error_message = "En phase allocate, les réservations IP NetBox doivent déjà exister (même state)."
  }
}
