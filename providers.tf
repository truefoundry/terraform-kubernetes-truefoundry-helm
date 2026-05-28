terraform {
  required_version = ">= 1.4.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
    # data.external used by the optional bash_check below. Only consulted when
    # the caller sets destroy_command; otherwise no plan-time bash dependency.
    external = {
      source  = "hashicorp/external"
      version = ">= 2.0.0"
    }
  }
}
