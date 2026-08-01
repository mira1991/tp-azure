# Reprise sur incident

Règle d'or : dans le workflow nominal comme en reprise, AUCUNE suppression
hors state. La remédiation privilégie toujours :

```text
détection → génération des blocs import → terraform plan → terraform apply
(imports) → terraform destroy
```

## Échec pendant l'allocation NetBox

Le state substrate contient exactement les ressources créées. Relancer
`destroy_substrate` (ou corriger puis re-`substrate_apply`). Aucun script de
libération d'IP : `terraform destroy` libère tout dans le bon ordre.

## Échec pendant la création Proxmox

Même state → même remède : `terraform destroy` supprime les VM partielles,
puis les IP, interfaces et VM NetBox. Les VM créées sont dans le state
(l'apply partiel les a enregistrées).

## Échec de Kolla-Ansible

Ne PAS toucher aux ressources Terraform. Choisir : conserver l'environnement
pour analyse (logs collectés en artefact) ou lancer le teardown complet.

## Échec du state openstack-config (API OpenStack indisponibles)

1. Tenter de restaurer les API (`kolla-ansible deploy` de rattrapage,
   redémarrage des conteneurs — voir TROUBLESHOOTING).
2. Retenter `destroy_openstack_config`.
3. Sauvegarder state et plan (artefacts du job).
4. Si les API sont définitivement mortes : décision manuelle de retirer les
   ressources du state —
   `terraform state rm <adresses>` (elles disparaîtront avec les VM).
5. Seulement après cette approbation : `destroy_substrate`.

## Échec du destroy substrate

- Le state est conservé, le job publie : plan destroy restant, erreurs
  provider, state final, IDs Proxmox/NetBox.
- Corriger la cause (VM verrouillée Proxmox, token expiré, NetBox
  indisponible…) puis jouer `retry_substrate_destroy`.
- Ne JAMAIS libérer les IP ni supprimer les objets NetBox à la main : le
  destroy suivant les traiterait comme dérive.

## Réconciliation d'orphelins (state perdu / ressources hors state)

```bash
# 1. Détection (lecture seule)
python3 scripts/detect-orphans.py --mode environment \
  --environment-id 142 \
  --state-json <(terraform -chdir=terraform/substrate show -json) \
  --out report.json --fail-on-orphans

# 2. Génération des blocs import
python3 scripts/generate-import-blocks.py --report report.json \
  --out terraform/substrate/imports.tf --orphans-only
# → RELIRE le fichier : certaines clés (<vm>/<rôle>) sont à compléter.

# 3. Import puis destruction PAR TERRAFORM
terraform -chdir=terraform/substrate plan     # contrôle des imports
terraform -chdir=terraform/substrate apply    # exécute les imports
rm terraform/substrate/imports.tf
terraform -chdir=terraform/substrate plan -destroy -out=tfdestroy.bin
python3 scripts/check-destroy-plan.py --plan-json <(terraform -chdir=terraform/substrate show -json tfdestroy.bin) --state substrate
terraform -chdir=terraform/substrate apply tfdestroy.bin
```

## Break-glass (dernier recours, jamais automatisé)

Conditions strictes : manuel, protégé, `environment_id` obligatoire,
confirmation explicite `FORCE_CLEANUP_CONFIRMATION=<nom exact de
l'environnement>`, vérification des tags avant chaque suppression, journal
complet, et interdiction absolue de toucher un VLAN/préfixe permanent ou un
objet sans tag `environment-<id>`.

Procédure : exécuter `detect-orphans.py` (rapport = périmètre exact), faire
valider le rapport par un pair, puis supprimer objet par objet via l'UI
NetBox/Proxmox en cochant chaque ligne du rapport. Ce chemin ne doit servir
que si l'import Terraform est impossible (objets corrompus). Aucune
suppression « par préfixe de nom » n'est autorisée.
