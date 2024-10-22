# Terraform Helm Chart Installation Module

This Terraform module provides a flexible way to install Helm charts on a Kubernetes cluster. It uses a `null_resource` with a `local-exec` provisioner to run Helm commands, allowing for dynamic chart installation and updates.

## Features

- Installs or upgrades Helm charts
- Supports custom repositories
- Allows for namespace creation
- Configurable chart values
- Uses temporary files for secure kubeconfig and values handling

## Requirements

- Terraform >= 0.13
- Helm (installed on the machine running Terraform)
- Access to a Kubernetes cluster

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `chart_name` | Name of the Helm chart to install | `string` | n/a | yes |
| `chart_version` | Version of the Helm chart to install | `string` | n/a | yes |
| `release_name` | Name for the Helm release | `string` | n/a | yes |
| `namespace` | Kubernetes namespace to install the release into | `string` | n/a | yes |
| `create_namespace` | Whether to create the namespace if it doesn't exist | `bool` | `false` | no |
| `repo_name` | Name of the Helm repository | `string` | n/a | yes |
| `repo_url` | URL of the Helm repository | `string` | n/a | yes |
| `cluster_ca_certificate` | Base64 encoded CA certificate of the Kubernetes cluster | `string` | n/a | yes |
| `cluster_endpoint` | Endpoint of the Kubernetes cluster | `string` | n/a | yes |
| `token` | Authentication token for the Kubernetes cluster | `string` | n/a | yes |
| `set_values` | Map of values to pass to the Helm chart | `any` | `{}` | no |

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

## Contributing

Contributions to improve this module are welcome. Please submit a pull request or open an issue on the repository.

## License

This module is released under the MIT License. See the [LICENSE](./LICENSE) file for more details.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [null_resource.helm_install](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_name"></a> [chart\_name](#input\_chart\_name) | n/a | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | n/a | `string` | n/a | yes |
| <a name="input_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#input\_cluster\_ca\_certificate) | n/a | `string` | n/a | yes |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | n/a | `string` | n/a | yes |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | n/a | `bool` | `false` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | n/a | `string` | n/a | yes |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | n/a | `string` | n/a | yes |
| <a name="input_repo_name"></a> [repo\_name](#input\_repo\_name) | n/a | `string` | n/a | yes |
| <a name="input_repo_url"></a> [repo\_url](#input\_repo\_url) | n/a | `string` | n/a | yes |
| <a name="input_set_values"></a> [set\_values](#input\_set\_values) | A map of values to pass to the Helm chart | `any` | `{}` | no |
| <a name="input_token"></a> [token](#input\_token) | n/a | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->