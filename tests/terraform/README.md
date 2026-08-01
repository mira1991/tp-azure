# Tests Terraform

Les tests unitaires Terraform (framework natif `terraform test` avec
providers **mockés**) vivent à côté du root module testé, comme l'exige le
framework :

    terraform/substrate/tests/topology.tftest.hcl

Exécution locale :

    cd terraform/substrate
    terraform init -backend=false
    terraform test

Ils vérifient sans aucun accès NetBox/Proxmox :

- la transformation profil YAML -> map de VM/interfaces (comptes exacts par
  profil `minimal` et `ha`) ;
- la convention de nommage `eph-osk-<usage>-<env>-<rôle>-<index>` ;
- l'unicité des clés `for_each` ;
- l'absence d'allocation IP sur le réseau provider (L2 pur) ;
- le placement `spread` déterministe ;
- le mode deux phases (`terraform_phase=allocate` => zéro VM Proxmox
  planifiée, allocations NetBox présentes dans le même state).

Le contrôle du **plan de destruction** (jamais de VLAN/préfixe/site/tenant
permanent supprimé) est couvert par `scripts/check-destroy-plan.py`, exécuté
sur chaque plan destroy en pipeline et testé unitairement dans
`tests/unit/test_check_destroy_plan.py`.
