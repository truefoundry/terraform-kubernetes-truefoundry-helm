variable "chart_name" {
  type        = string
  description = "Name of the chart"
}

variable "chart_version" {
  type        = string
  description = "Version of the chart"
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

variable "cluster_ca_certificate" {
  type        = string
  description = "CA certificate of the cluster"
}

variable "cluster_endpoint" {
  type        = string
  description = "Endpoint of the cluster"
}

variable "cluster_name" {
  type        = string
  description = "Name of the cluster"
}

variable "set_values" {
  type        = any
  description = "A map of values to pass to the Helm chart"
  default     = {}
}
variable "trigger_helm_update" {
  description = "Set this to any value to trigger a Helm chart update"
  type        = string
  default     = null
}
