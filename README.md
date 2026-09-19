# tp-azure

Terraform code and GitLab CI pipeline that build a small web stack on
OpenStack: a private network behind a router, a security group, and a set of
nginx instances with optional floating IPs and data volumes.

```
.
├── .gitlab-ci.yml              # validate -> plan -> network -> security -> compute
├── .tflint.hcl
├── Makefile                    # the same layered rollout, locally
├── docs/infrastructure.md      # architecture, variables, local usage
├── index.php                   # legacy demo page kept from the original project
└── terraform/
    ├── versions.tf
    ├── providers.tf
    ├── variables.tf
    ├── main.tf
    ├── outputs.tf
    ├── environments/           # dev.tfvars, staging.tfvars, prod.tfvars
    └── modules/
        ├── network/
        ├── security/
        └── compute/
```

## Quick start

1. Add the OpenStack credentials as masked CI/CD variables. The full list is in
   [docs/infrastructure.md](docs/infrastructure.md#required-cicd-variables).
2. Open a merge request. The pipeline validates, lints and scans the code, then
   plans the `dev` environment and attaches the plan to the merge request.
3. Merge, then start the rollout. The stack is created one layer at a time,
   `module.network` first, then `module.security`, then an untargeted apply
   that converges the rest. Only the first layer needs a click.

[docs/infrastructure.md](docs/infrastructure.md) covers the module layout, the
pipeline, and how to run the same steps locally.
