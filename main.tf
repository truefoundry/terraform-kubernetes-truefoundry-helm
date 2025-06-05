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

# Main resource for Helm installation
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
