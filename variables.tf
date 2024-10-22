variable "chart_name" {
  type = string
}

variable "chart_version" {
  type = string
}

variable "release_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "create_namespace" {
  type    = bool
  default = false
}

variable "repo_name" {
  type = string
}

variable "repo_url" {
  type = string
}

variable "cluster_ca_certificate" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "token" {
  type = string
}

variable "set_values" {
  type        = any
  description = "A map of values to pass to the Helm chart"
  default     = {}
}
