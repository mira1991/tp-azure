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

Every resource is prefixed with `<project_name>-<environment>`, for example
`tp-dev-net`, `tp-dev-web-01`. Changing either input therefore replaces the
whole stack, which is what keeps environments isolated.

The network module resolves the external network once and exports its name as
the floating IP pool, so the router uplink and the floating IPs cannot drift
apart. Its `subnet_id` output waits for the router interface, which is what
orders instance boot after the route out exists.

## State

State is kept in the GitLab-managed Terraform state backend, one state file per
environment selected by `TF_STATE_NAME`. The `backend "http"` block in
`terraform/versions.tf` is empty on purpose: `gitlab-terraform init` injects the
address, lock and unlock URLs, and the job token credentials.

`TF_STATE_NAME` is the only place an environment is named in CI. The variables
file, the GitLab environment and the `resource_group` concurrency lock are all
derived from it, so a job cannot plan one environment against another's state.

## Pipeline

| Stage | Jobs | Trigger |
| --- | --- | --- |
| validate | `validate` (fmt, init, validate), `tflint`, `security_scan` | every pipeline |
| plan | `plan:dev` | merge requests and the default branch |
| plan | `plan:staging`, `plan:prod` | default branch, and tags for `plan:prod` |
| apply-network | `network:<env>` | manual, default branch |
| apply-security | `security:<env>` | after the network layer |
| apply-compute | `compute:<env>` | after the security layer |
| destroy | `destroy:<env>` | manual, default branch |

`plan.json` from the plan stage is published as a Terraform report, which is
what puts the resource counts in the merge request.

## Creating the resources by target, one layer per stage

The stack is built in dependency order rather than in a single apply. Each
stage plans and applies one layer with `-target`:

| Stage | Target | Creates |
| --- | --- | --- |
| `apply-network` | `module.network` | network, subnet, router, router interface |
| `apply-security` | `module.security` | security group and its rules |
| `apply-compute` | none | keypair, ports, instances, floating IPs, volumes, and anything the earlier targets skipped |

Three properties follow from this shape:

- A failure stops the rollout at the layer that broke. The pipeline does not
  half-build the stack and then fail on an unrelated resource.
- Terraform pulls in whatever a target depends on, so the layers can be applied
  in order without listing individual resources.
- The last stage runs **without** `-target`, so it converges the full
  configuration. Targeted applies are a partial operation by design, and this
  final untargeted pass is what guarantees the state matches the code.

Only the first layer is a manual gate. Once the network is approved the
remaining layers run on their own, so a rollout is one click rather than three.
Each layer takes the same `resource_group` lock, so two pipelines cannot
interleave layers on the same environment.

The same sequence exists locally in the `Makefile`:

```bash
make plan ENV=dev        # full plan, nothing applied
make network ENV=dev     # -target=module.network
make security ENV=dev    # -target=module.security
make compute ENV=dev     # untargeted, converges everything
make up ENV=dev          # the three layers in order
make destroy ENV=dev
```

`tflint` and `security_scan` (Checkov) are advisory: they report findings
without blocking. The workflow rules keep one pipeline per change, so a push to
a branch with an open merge request does not run everything twice.

## Required CI/CD variables

Set these under Settings > CI/CD > Variables, masked and protected. This table
is the only list; the pipeline and the README point here.

| Variable | Example | Required |
| --- | --- | --- |
| `TF_VAR_os_auth_url` | `https://keystone.example.net:5000/v3` | yes |
| `TF_VAR_os_user_name` | `terraform` | yes |
| `TF_VAR_os_password` | masked secret | yes |
| `TF_VAR_os_project_name` | `infra` | yes |
| `TF_VAR_ssh_public_key` | `ssh-ed25519 AAAA...` | yes |
| `TF_VAR_os_region` | `RegionOne` | defaults to `RegionOne` |
| `TF_VAR_os_user_domain_name` | `Default` | defaults to `Default` |
| `TF_VAR_os_project_domain_name` | `Default` | defaults to `Default` |
| `TF_VAR_os_cacert_file` | path to a PEM bundle | only for a private CA |

No credential belongs in a `.tfvars` file. The files under
`terraform/environments/` carry only the values that differ from the defaults in
`terraform/variables.tf`: subnet, instance count, flavor, volume size, SSH
source ranges and the cost-center tag.

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

To build it layer by layer instead, use the `Makefile` targets shown above.

To work against the GitLab state instead, run `gitlab-terraform init` inside the
same image CI uses, or follow GitLab's managed Terraform state documentation to
pass the `-backend-config` flags with a personal access token that has the `api`
scope.

## Operational notes

- The Glance image is resolved by exact name, so `image_name` must match one
  image. A new OS image is rolled by bumping `image_name`, which shows up as a
  normal plan and goes through the manual apply gate.
- `ssh_allowed_cidrs` defaults to `0.0.0.0/0` for the lab. Staging and
  production already narrow it to `10.0.0.0/8`.
- `data_volume_size = 0` disables the Cinder volume entirely, which is the
  default and what `dev` uses.
- For a cloud with a private CA, set `TF_VAR_os_cacert_file` to a PEM bundle
  supplied as a CI file variable. There is deliberately no switch to turn
  certificate verification off.
- `terraform/.terraform.lock.hcl` is not committed yet. Run `terraform init`
  once from a host that can reach `registry.terraform.io` and commit the result,
  which also makes the pipeline's provider cache key effective.
