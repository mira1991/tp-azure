# Terraform OpenStack infrastructure

This document describes what the pipeline builds, how state is handled and how
to run the same steps from a laptop.

## What gets created

Per environment (`dev`, `staging`, `prod`), the root module composes three
local modules:

| Module | Resources |
| --- | --- |
| `modules/network` | private network, DHCP subnet, router uplinked to the external network, router interface |
| `modules/security` | security group with SSH, HTTP, HTTPS ingress, ICMP and intra-group traffic, open IPv4 egress |
| `modules/compute` | keypair, one Neutron port per instance, Nova instances booted from a Glance image, optional floating IPs, optional Cinder data volumes |

Instances are provisioned by cloud-init, which installs nginx and writes a page
carrying the host name, environment and node index.

## Naming

Every resource is prefixed with `<project_name>-<environment>`, for example
`tp-dev-net`, `tp-dev-web-01`. Changing `project_name` or `environment`
therefore replaces the whole stack, which is what keeps environments isolated.

## State

State is kept in the GitLab-managed Terraform state backend, one state file per
environment selected by `TF_STATE_NAME`. The `backend "http"` block in
`terraform/versions.tf` is empty on purpose: `gitlab-terraform init` injects the
address, lock and unlock URLs, and the job token credentials.

The `apply` jobs declare `resource_group: ${TF_STATE_NAME}`, so two pipelines can
never apply the same environment at the same time.

## Pipeline

| Stage | Jobs | Trigger |
| --- | --- | --- |
| validate | `fmt`, `validate`, `tflint`, `security_scan` | every branch and merge request |
| plan | `plan:dev` | merge requests and the default branch |
| plan | `plan:staging`, `plan:prod` | default branch (`plan:prod` also on tags) |
| apply | `apply:dev`, `apply:staging`, `apply:prod` | manual, default branch |
| destroy | `destroy:dev`, `destroy:staging`, `destroy:prod` | manual, default branch |

`plan` writes both `plan.cache` and `plan.json`. The JSON is published as a
Terraform report, so merge requests show the resource counts inline. The apply
job consumes `plan.cache`, which means it applies exactly what was reviewed.

`tflint` and `security_scan` (Checkov) are advisory: they report findings
without blocking the pipeline.

## Required CI/CD variables

Set these under Settings > CI/CD > Variables, masked and protected:

| Variable | Example |
| --- | --- |
| `TF_VAR_os_auth_url` | `https://keystone.example.net:5000/v3` |
| `TF_VAR_os_user_name` | `terraform` |
| `TF_VAR_os_password` | masked secret |
| `TF_VAR_os_project_name` | `infra` |
| `TF_VAR_os_region` | `RegionOne` |
| `TF_VAR_os_user_domain_name` | `Default` |
| `TF_VAR_os_project_domain_name` | `Default` |
| `TF_VAR_ssh_public_key` | `ssh-ed25519 AAAA...` |

No credential belongs in a `.tfvars` file. The files under
`terraform/environments/` only carry sizing and network settings.

## Running locally

```bash
export TF_VAR_os_auth_url=https://keystone.example.net:5000/v3
export TF_VAR_os_user_name=terraform
export TF_VAR_os_password='...'
export TF_VAR_os_project_name=infra
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"

cd terraform
terraform init -backend=false            # local run, no GitLab state
terraform validate
terraform plan  -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

To work against the GitLab state from a laptop, initialize the HTTP backend
with a personal access token that has the `api` scope:

```bash
PROJECT_ID=<numeric project id>
STATE=dev
terraform init \
  -backend-config="address=https://gitlab.example.net/api/v4/projects/${PROJECT_ID}/terraform/state/${STATE}" \
  -backend-config="lock_address=https://gitlab.example.net/api/v4/projects/${PROJECT_ID}/terraform/state/${STATE}/lock" \
  -backend-config="unlock_address=https://gitlab.example.net/api/v4/projects/${PROJECT_ID}/terraform/state/${STATE}/lock" \
  -backend-config="username=${GITLAB_USER}" \
  -backend-config="password=${GITLAB_TOKEN}" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="retry_wait_min=5"
```

## Operational notes

- The compute module ignores changes to `image_id`. A refreshed upstream image
  will not silently rebuild every instance; bump `image_name` or taint the
  instance when a rebuild is wanted.
- `ssh_allowed_cidrs` defaults to `0.0.0.0/0` for the lab. Narrow it to the
  bastion or VPN range for staging and production.
- `data_volume_size = 0` disables the Cinder volume entirely, which is the
  default for `dev`.
- Floating IPs come from the pool named by `external_network_name`; the same
  network is used as the router uplink.

## Dependency lock file

`terraform/.terraform.lock.hcl` is not committed yet because the provider
registry is not reachable from the environment this code was written in. Run
`terraform init` once against a host that can reach `registry.terraform.io`,
then commit the generated lock file so every pipeline run resolves the same
provider build.
