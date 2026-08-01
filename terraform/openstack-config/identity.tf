# Identité : projet, utilisateur technique et rôles de test.
#
# L'utilisateur de test est créé SANS mot de passe (il ne peut pas se
# connecter) : il valide la chaîne Keystone (création, rôles, quotas par
# projet) sans placer aucun secret dans le state Terraform. Les smoke tests
# s'authentifient avec les credentials admin fournis par le job (openrc).

data "openstack_identity_role_v3" "member" {
  name = "member"
}

resource "openstack_identity_project_v3" "smoke" {
  name        = "${var.environment_name}-smoke"
  description = var.smoke_project_description
  enabled     = true
  tags        = ["eph", "environment-${var.environment_id}"]
}

resource "openstack_identity_user_v3" "smoke" {
  name               = "${var.environment_name}-smoke-user"
  description        = "Utilisateur technique de test (sans mot de passe) — managed-by: terraform-gitlab"
  default_project_id = openstack_identity_project_v3.smoke.id
  enabled            = true

  # Pas d'attribut password : aucun secret dans les variables ni dans le state.
}

resource "openstack_identity_role_v3" "observer" {
  name = "${var.environment_name}-observer"
}

resource "openstack_identity_role_assignment_v3" "smoke_member" {
  user_id    = openstack_identity_user_v3.smoke.id
  project_id = openstack_identity_project_v3.smoke.id
  role_id    = data.openstack_identity_role_v3.member.id
}

resource "openstack_identity_role_assignment_v3" "smoke_observer" {
  user_id    = openstack_identity_user_v3.smoke.id
  project_id = openstack_identity_project_v3.smoke.id
  role_id    = openstack_identity_role_v3.observer.id
}
