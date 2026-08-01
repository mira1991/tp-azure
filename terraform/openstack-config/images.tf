# Image de test (CirrOS).
#
# Deux modes d'approvisionnement :
#   - test_image_local_path : fichier présent dans le job CI (miroir hors
#     ligne, recommandé en environnement isolé) ;
#   - test_image_source_url : téléchargement par le job Terraform.

resource "openstack_images_image_v2" "cirros" {
  name             = var.test_image_name
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  protected        = false

  local_file_path  = var.test_image_local_path != "" ? var.test_image_local_path : null
  image_source_url = var.test_image_local_path == "" ? var.test_image_source_url : null

  min_disk_gb = 1
  min_ram_mb  = 128

  properties = {
    hw_rng_model = "virtio"
  }

  tags = ["eph", "environment-${var.environment_id}"]
}
