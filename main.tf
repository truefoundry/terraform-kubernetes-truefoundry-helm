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
#     on every existing release. Depending on the chart, a forced reinstall can
#     have unwanted side effects (e.g. helm hooks re-firing), so we keep the
#     install lifecycle untouched.
#   - Iterating on destroy_command (e.g. editing the command) would also
#     recreate helm_install if they shared triggers. Decoupling means command
#     edits never touch the install lifecycle.
#
# Create-order: depends_on helm_install → so on destroy, this resource is
# torn down FIRST (reverse-graph order). Its when=destroy provisioner runs
# while the release it targets is still present.
# A `count` gate keeps the resource entirely absent when no hook is wanted —
# so existing releases that don't yet pass destroy_command see zero new
# resources in plan, only the install they already have.
#
# destroy_command is an opaque, caller-supplied string: this module does not
# know or assume what it does. The comments below cover the resource lifecycle
# only.
resource "null_resource" "helm_destroy_hook" {
  count = trimspace(var.destroy_command) != "" ? 1 : 0

  depends_on = [null_resource.helm_install]

  # destroy_command is the only thing the hook tracks in triggers. Anything that
  # rotates every plan (tokens, generated kubeconfigs, etc.) is deliberately kept
  # out — including it would force-recreate the resource on every apply. How the
  # command authenticates to the cluster is the caller's concern.
  triggers = {
    destroy_command = var.destroy_command
  }

  # Freeze triggers after first apply. Without this, editing var.destroy_command
  # would mutate the trigger, force-replace this resource, and fire the OLD
  # destroy command during a routine apply against a live cluster — running a
  # teardown the operator never intended when they only meant to edit config.
  # Trade-off: command updates require `terraform apply
  # -replace=module.<name>.null_resource.helm_destroy_hook[0]` while the
  # cluster is quiescent. To retire the hook on a live cluster, use
  # `terraform state rm` rather than setting destroy_command = "" (a count
  # flip to 0 would also fire the captured command).
  lifecycle {
    ignore_changes = [triggers]
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    command     = self.triggers.destroy_command
  }
}
