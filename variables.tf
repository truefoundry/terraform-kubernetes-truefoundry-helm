variable "chart_name" {
  type        = string
  description = "Name of the chart"
}

variable "chart_version" {
  description = "Version of the Helm chart to install. If not specified, the latest version will be used."
  type        = string
  default     = ""
}

variable "release_name" {
  type        = string
  description = "Release name of the chart"
}

variable "namespace" {
  type        = string
  description = "Namespace to install the chart"
}

variable "create_namespace" {
  type        = bool
  default     = false
  description = "Create the namespace if it does not exist. Defaults to false"
}

variable "repo_name" {
  type        = string
  description = "Name of the Helm repository"
}

variable "repo_url" {
  type        = string
  description = "URL of the Helm repository"
}

variable "set_values" {
  type        = any
  description = "A map of values to pass to the Helm chart"
  default     = {}
}

variable "always_update" {
  description = "Set this to true value trigger a Helm chart update"
  type        = bool
  default     = false
}

variable "kubeconfig_json" {
  description = "Kubeconfig JSON"
  type        = string
}

# -----------------------------------------------------------------------------
# Optional destroy-time hook
# -----------------------------------------------------------------------------
# Generic "run this bash on tofu destroy" escape hatch so callers can clean up
# cloud resources the chart created out-of-band (e.g. Karpenter EC2 instances,
# AWS-LB-Controller NLBs) BEFORE the surrounding cluster/network is torn down.
# Empty string disables the hook entirely (no resource created).
#
# The hook lives in a separate null_resource (helm_destroy_hook) so its
# lifecycle is decoupled from the helm install — script edits do not force
# `helm install` to re-run. Any env the script needs must be baked into the
# command string by the caller (triggers only hold strings, so we deliberately
# don't accept a map; we also don't put KUBECONFIG_JSON in the env because its
# token rotates every plan, which would defeat the decoupling. The recommended
# pattern is for the script body to build its own kubeconfig via
# `aws eks update-kubeconfig` exec-auth using cluster_name + region baked into
# the command string).
variable "destroy_command" {
  description = "Bash command run by a `when = destroy` local-exec. Empty string disables the hook (no resource created). The caller is responsible for baking any required env into the command body."
  type        = string
  default     = ""
}
