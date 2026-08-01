# Backend HTTP GitLab.
#
# Toute la configuration (adresses state/lock/unlock, méthodes POST/DELETE,
# retries, authentification) est fournie par variables d'environnement
# TF_HTTP_* dans les jobs CI (scripts/terraform-env.sh) :
#   TF_HTTP_ADDRESS        = .../terraform/state/<ENVIRONMENT_NAME>-substrate
#   TF_HTTP_LOCK_ADDRESS   = <ADDRESS>/lock     (TF_HTTP_LOCK_METHOD=POST)
#   TF_HTTP_UNLOCK_ADDRESS = <ADDRESS>/lock     (TF_HTTP_UNLOCK_METHOD=DELETE)
#   TF_HTTP_RETRY_MAX, TF_HTTP_USERNAME, TF_HTTP_PASSWORD
#
# Aucun secret de backend n'est donc écrit dans les fichiers .tf ni dans les
# plans.
terraform {
  backend "http" {}
}
