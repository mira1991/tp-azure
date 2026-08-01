# Provider OpenStack du state "openstack-config".
#
# L'authentification passe exclusivement par l'environnement du job GitLab :
# un clouds.yaml temporaire (0600, supprimé par trap) est généré par
# scripts/render-terraform-outputs.py à partir des passwords Kolla, puis
# OS_CLOUD est exporté. Aucun mot de passe OpenStack ne transite par les
# variables Terraform ni ne finit dans le state ou les plans.

provider "openstack" {
  # Entièrement configuré par variables d'environnement (OS_CLOUD / OS_*).
}
