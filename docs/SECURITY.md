# Sécurité

## Principes

- Aucun secret versionné (contrôlé par gitleaks en CI et pre-commit).
- Credentials providers uniquement par variables d'environnement
  (`scripts/terraform-env.sh`) : jamais en variables Terraform, jamais dans
  les `.tf`, donc jamais dans les plans archivés.
- Jamais de `set -x` dans les jobs manipulant des secrets ; fichiers
  sensibles en 0600, supprimés par `trap` (`shred`).
- Clés privées SSH uniquement en mémoire d'agent (`.ssh_agent`).
- `passwords.yml` : voir `docs/KOLLA.md` — jamais dans un state Terraform,
  jamais en artefact public (accès `developer`, expiration courte, ou mode
  Vault sans artefact).
- `clouds.yaml` : reconstruit à la volée dans chaque job consommateur,
  jamais artefacté.
- Le state Terraform peut contenir des informations sensibles
  (IP, topologie) : restreindre l'accès au projet GitLab (le state est
  accessible aux rôles Maintainer/Developer selon la configuration de
  l'instance) et ne jamais l'exposer en artefact.

## Variables GitLab attendues

Sensibles — à créer **masked** (+ **protected** si refs protégées), scope
minimal :

```text
PROXMOX_TOKEN_SECRET      NETBOX_TOKEN            SSH_PRIVATE_KEY
PROXMOX_SSH_PRIVATE_KEY   KOLLA_REGISTRY_PASSWORD
VAULT_ROLE_ID             VAULT_SECRET_ID
TF_HTTP_PASSWORD (si backend externe — sinon CI_JOB_TOKEN implicite)
```

Non sensibles :

```text
PROXMOX_API_URL PROXMOX_TOKEN_ID PROXMOX_INSECURE PROXMOX_TARGET_NODES
PROXMOX_POOL PROXMOX_TEMPLATE PROXMOX_TEMPLATE_NODE PROXMOX_STORAGE
PROXMOX_SNIPPETS_STORAGE NETBOX_URL NETBOX_SITE NETBOX_TENANT NETBOX_CLUSTER
NETBOX_VLAN_GROUP NETBOX_VRF NETWORK_ROLE_* SSH_PUBLIC_KEY SSH_KNOWN_HOSTS
KOLLA_REGISTRY KOLLA_REGISTRY_NAMESPACE KOLLA_REGISTRY_USERNAME
KOLLA_IMAGE_TAG VAULT_ADDR KOLLA_VAULT_PASSWORDS_PATH
TF_HTTP_ADDRESS TF_HTTP_LOCK_ADDRESS TF_HTTP_UNLOCK_ADDRESS TF_HTTP_USERNAME
```

## Moindre privilège

- Token NetBox : limiter aux apps virtualization/ipam/extras ; pas de
  droits sur dcim au-delà de la lecture.
- Token Proxmox : rôles `PVEVMAdmin` + `PVEDatastoreUser` sur les chemins
  nécessaires, pas `Administrator`.
- Job token GitLab : suffit pour le backend Terraform et le trigger de
  pipelines du même projet — aucun PAT requis dans le workflow nominal.
- Vault : AppRole dédié en lecture seule sur le chemin des passwords.

## Périmètre des artefacts

Voir `docs/PIPELINE.md` (section Artefacts) : plans et outputs en accès
`developer`, secrets jamais artefactés, JUnit/logs publics acceptables.
