# Backend HTTP GitLab — state eph-osk-<...>-openstack-config, distinct du
# state substrate. Configuration par variables d'environnement TF_HTTP_*
# (scripts/terraform-env.sh), aucun secret dans les fichiers .tf.
#
# Ce state doit être détruit AVANT le substrate : il dépend des API OpenStack
# hébergées par les VM du substrate (voir docs/TEARDOWN.md).
terraform {
  backend "http" {}
}
