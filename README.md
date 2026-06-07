# Terraform Helm Chart Installation Module

This Terraform module provides a flexible way to install Helm charts on a Kubernetes cluster. It uses a `null_resource` with a `local-exec` provisioner to run Helm commands, allowing for dynamic chart installation and updates.

## Features

- Installs or upgrades Helm charts
- Supports custom repositories
- Allows for namespace creation
- Configurable chart values
- Uses temporary files for secure kubeconfig and values handling
- Optional pre-destroy teardown hook via `destroy_command`

## Requirements

- Terraform >= 1.4.0
- Helm (installed on the machine running Terraform)
- Access to a Kubernetes cluster
- For the optional `destroy_command` hook: `bash` on `PATH`, plus whatever tools
  the command itself invokes — see
  [Shell requirement](#shell-requirement-windows-not-supported)

## How it works

1. The module creates temporary files for the kubeconfig and chart values.
2. It then uses these temporary files to run Helm commands via a `local-exec` provisioner.
3. The Helm repository is added and updated.
4. The chart is installed or upgraded using the provided values.
5. Temporary files are cleaned up after the Helm command execution.

## Notes

- Ensure that the machine running Terraform has Helm installed and configured.
- The module uses a `null_resource` with a `local-exec` provisioner, which means the Helm commands are executed on the machine running Terraform, not within Terraform itself.
- Be cautious with sensitive information in `set_values`. While this module uses temporary files, it's generally a good practice to manage secrets separately.

## Shell requirement (Windows not supported)

This module shells out via `local-exec` provisioners, so it requires a POSIX
shell environment on the machine running Terraform. **Windows-native runners are
not supported — run from WSL, Linux, or macOS.**

- `null_resource.helm_install` runs under the default `local-exec` shell
  (`/bin/sh` on Unix) and uses POSIX heredocs plus `helm`. It needs `helm` on
  `PATH`.
- The optional `destroy_command` hook (`null_resource.helm_destroy_hook`) runs
  explicitly under `bash` (`interpreter = ["bash", "-c"]`), so **`bash` must be
  on `PATH`** for the command to run. The command is caller-supplied and may need
  additional tools on `PATH` depending on what it does.

There is no plan-time guard for these requirements: a missing shell, `bash`, or
`helm` surfaces as a provisioner launch/exit failure at `apply`/`destroy` time.
Because the teardown never starts when `bash` is absent, no partial destroy
occurs — the operation simply fails. Re-run from a supported environment to
recover.

### Recovering a `destroy` when `bash` is unavailable

If `null_resource.helm_destroy_hook` is already in state and you run
`terraform destroy` on a host without `bash`, the destroy **starts** (there is no
plan-time bash dependency) but fails the moment Terraform invokes the
`when = destroy` provisioner:

```
Error: running "bash -c ...": exec: "bash": executable file not found in $PATH
```

A failed destroy-time provisioner aborts the destroy and leaves the resource in
state. Because the hook `depends_on` `helm_install`, it is torn down **first**
(reverse-graph order), so the failure happens before anything else is destroyed —
nothing is left half-torn-down, and you are in a clean, recoverable spot.

**Option 1 — run the destroy from a `bash`-capable host (preferred, no data loss).**
Re-run `terraform destroy` from WSL, Linux, or macOS with `bash` (and whatever
else your `destroy_command` invokes) on `PATH`. The `destroy_command` runs and the
rest of the stack destroys normally. This is the intended path.

**Option 2 — drop the hook from state and skip the teardown (escape hatch).**

```bash
terraform state rm 'module.<name>.null_resource.helm_destroy_hook[0]'
terraform destroy
```

`state rm` makes Terraform forget the resource **without running its destroy
provisioner**, so the destroy proceeds without `bash`. The cost: the
`destroy_command` never runs, so **whatever cloud resources it was responsible for
cleaning up may be orphaned** — and orphaned resources can block downstream
destroys (e.g. a VPC that still has attached ENIs). Take this path only if `bash`
is truly unobtainable, and plan to clean up those resources manually or run your
`destroy_command` logic separately from a `bash`-capable host.

### Managing the `destroy_command` hook

- The hook's `triggers` are frozen after first apply (`ignore_changes`). To
  update the script on an existing resource, run
  `terraform apply -replace='module.<name>.null_resource.helm_destroy_hook[0]'`
  while the cluster is quiescent.
- To retire the hook on a live cluster, use
  `terraform state rm 'module.<name>.null_resource.helm_destroy_hook[0]'` rather
  than setting `destroy_command = ""` — flipping the count to 0 would fire the
  captured teardown script.

## Contributing

Contributions to improve this module are welcome. Please submit a pull request or open an issue on the repository.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [null_resource.helm_destroy_hook](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.helm_install](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_always_update"></a> [always\_update](#input\_always\_update) | Set this to true value trigger a Helm chart update | `bool` | `false` | no |
| <a name="input_chart_name"></a> [chart\_name](#input\_chart\_name) | Name of the chart | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Version of the Helm chart to install. If not specified, the latest version will be used. | `string` | `""` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Create the namespace if it does not exist. Defaults to false | `bool` | `false` | no |
| <a name="input_destroy_command"></a> [destroy\_command](#input\_destroy\_command) | Bash command run by a `when = destroy` local-exec. Empty string disables the hook (no resource created). The caller is responsible for baking any required env into the command body. | `string` | `""` | no |
| <a name="input_kubeconfig_json"></a> [kubeconfig\_json](#input\_kubeconfig\_json) | Kubeconfig JSON | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace to install the chart | `string` | n/a | yes |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Release name of the chart | `string` | n/a | yes |
| <a name="input_repo_name"></a> [repo\_name](#input\_repo\_name) | Name of the Helm repository | `string` | n/a | yes |
| <a name="input_repo_url"></a> [repo\_url](#input\_repo\_url) | URL of the Helm repository | `string` | n/a | yes |
| <a name="input_set_values"></a> [set\_values](#input\_set\_values) | A map of values to pass to the Helm chart | `any` | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->