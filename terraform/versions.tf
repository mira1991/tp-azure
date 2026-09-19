terraform {
  required_version = ">= 1.6.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }

  # State is stored in the GitLab-managed Terraform state backend.
  # All settings are injected by `gitlab-terraform init` in CI, so the
  # block stays empty here (see .gitlab-ci.yml).
  backend "http" {}
}
