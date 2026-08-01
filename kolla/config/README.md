# kolla/config/

Surcharges de configuration des services Kolla (copiées vers
`$KOLLA_CONFIG_DIR/config/` par le job `kolla_generate_config`).

Convention Kolla-Ansible : un sous-répertoire ou fichier par service, par
exemple :

    config/
    ├── neutron/ml2_conf.ini      # surcharge ML2
    ├── nova.conf                  # surcharge globale nova
    └── glance-api.conf

Aucun secret ici : ce répertoire est versionné.
