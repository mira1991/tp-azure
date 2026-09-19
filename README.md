# tp-azure

Terraform code and GitLab CI pipeline that build a small web stack on
OpenStack: a private network behind a router, a security group, and a set of
nginx instances with optional floating IPs and data volumes.

```
.
├── .gitlab-ci.yml              # validate -> plan -> apply -> destroy, per environment
├── .tflint.hcl                 # linter rules
├── docs/infrastructure.md      # architecture, variables, local usage
├── index.php                   # legacy demo page kept from the original project
└── terraform/
    ├── versions.tf             # provider constraints, GitLab http state backend
    ├── providers.tf            # OpenStack provider wiring
    ├── variables.tf            # inputs, credentials come from TF_VAR_* CI variables
    ├── main.tf                 # composes the three modules
    ├── outputs.tf
    ├── environments/           # dev.tfvars, staging.tfvars, prod.tfvars
    └── modules/
        ├── network/            # network, subnet, router, router interface
        ├── security/           # security group and rules
        └── compute/            # keypair, ports, instances, floating IPs, volumes
```

## Quick start

1. Add the OpenStack credentials as masked CI/CD variables
   (`TF_VAR_os_auth_url`, `TF_VAR_os_user_name`, `TF_VAR_os_password`,
   `TF_VAR_os_project_name`, `TF_VAR_ssh_public_key`).
2. Open a merge request. The pipeline formats, validates, lints and scans the
   code, then plans the `dev` environment and attaches the plan to the MR.
3. Merge. The `apply:dev` job on the default branch is manual, so nothing
   reaches the cloud without a click.
4. `staging` and `prod` follow the same plan-then-manual-apply path, with a
   `resource_group` lock per environment.

Full details, including how to run the same steps locally, are in
[docs/infrastructure.md](docs/infrastructure.md).
