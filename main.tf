locals {
  # Get latest version if chart_version is not specified
  helm_version_flag = var.chart_version != "" ? "--version ${var.chart_version}" : ""

  # Helm command configuration
  helm_command = <<-EOT
    helm upgrade --install ${var.release_name} ${var.repo_name}/${var.chart_name} \
      ${local.helm_version_flag} \
      --namespace ${var.namespace} \
      ${var.create_namespace ? "--create-namespace" : ""} \
      -f $VALUES_FILE \
      --debug
  EOT
}

# Main resource for Helm installation.
# Triggers intentionally unchanged from earlier module versions — adding new
# trigger keys here would force-recreate this resource on upgrade and re-run
# `helm install` once on every existing cluster (and again on every script edit
# that affected the new keys). The destroy hook lives in its own resource below
# so its lifecycle is decoupled from the install.
resource "null_resource" "helm_install" {
  triggers = {
    chart_name    = var.chart_name
    chart_version = var.chart_version
    release_name  = var.release_name
    namespace     = var.namespace
    always_update = var.always_update != false ? timestamp() : "initial"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting Helm install process..."

      # Create temporary files
      export KUBECONFIG=$(mktemp)
      VALUES_FILE=$(mktemp)
      echo "Created temporary files: KUBECONFIG=$KUBECONFIG, VALUES_FILE=$VALUES_FILE"

      # Generate kubeconfig
      cat <<EOF > $KUBECONFIG
      ${var.kubeconfig_json}
      EOF
      echo "Generated kubeconfig file"

      # Generate values file
      cat <<EOF > $VALUES_FILE
      ${jsonencode(var.set_values)}
      EOF
      echo "Generated values file"

      # Execute Helm commands
      echo "Executing Helm commands..."
      helm repo add ${var.repo_name} ${var.repo_url}
      helm repo update ${var.repo_name}
      ${local.helm_command}

      HELM_EXIT_CODE=$?
      echo "Helm command completed with exit code: $HELM_EXIT_CODE"

      # Cleanup
      rm $KUBECONFIG $VALUES_FILE
      echo "Cleaned up temporary files"

      exit $HELM_EXIT_CODE
    EOT
  }
}

# Optional destroy-time hook, decoupled from helm_install.
#
# Why a separate resource (not a second provisioner on helm_install):
#   - On upgrade from a prior helm-module version, adding triggers to
#     helm_install would force-recreate it and re-run `helm upgrade --install`
#     on every existing cluster. The inframold chart is intended to be
#     bootstrapped once (it carries `helm.sh/resource-policy: keep` and hands
#     off to ArgoCD), so a forced reinstall has unwanted side effects
#     (pre-sync hooks re-fire, etc.).
#   - Iterating on destroy_command (e.g. editing the teardown script) would
#     also recreate helm_install if they shared triggers. Decoupling means
#     script edits never touch the install lifecycle.
#
# Create-order: depends_on helm_install → so on destroy, this resource is
# torn down FIRST (reverse-graph order). Its when=destroy provisioner runs
# while everything (cluster API, controllers, ArgoCD) is still alive.
# A `count` gate keeps the resource entirely absent when no hook is wanted —
# so existing clusters that don't yet pass destroy_command see zero new
# resources in plan, only the install they already have.
# Plan-time bash availability check. Surfaces the bash requirement as a clear
# plan-stage error on Windows-native runners (and any runner missing bash) so
# operators don't hit a cryptic shell error mid-destroy. Both the install
# provisioner (interpreter=/bin/bash, uses heredocs and helm) and the destroy
# hook below require bash; this guard is intentionally scoped to the destroy
# path because that's where data loss from an unexpected failure is hardest to
# recover from.
data "external" "bash_check" {
  count   = var.destroy_command != "" ? 1 : 0
  program = ["bash", "-c", "printf '{\"version\":\"%s\"}' \"$BASH_VERSION\""]
}

resource "terraform_data" "bash_required" {
  count = var.destroy_command != "" ? 1 : 0
  lifecycle {
    precondition {
      condition     = length(data.external.bash_check) > 0 && data.external.bash_check[0].result.version != ""
      error_message = "destroy_command requires bash on the runner's PATH. This module does not support Windows-native runners — use WSL/Linux/macOS, or unset destroy_command (the surrounding cluster destroy may then leave orphaned cloud resources)."
    }
  }
}

resource "null_resource" "helm_destroy_hook" {
  count = var.destroy_command != "" ? 1 : 0

  depends_on = [null_resource.helm_install, terraform_data.bash_required]

  # destroy_command is the only thing the hook needs. We deliberately keep
  # KUBECONFIG_JSON out of triggers (its token rotates every plan and would
  # force-recreate the resource every apply); the caller's script body should
  # build a kubeconfig via `aws eks update-kubeconfig` exec-auth.
  triggers = {
    destroy_command = var.destroy_command
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = self.triggers.destroy_command
  }
}
