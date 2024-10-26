data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}
resource "null_resource" "helm_install" {
  triggers = {
    chart_name     = var.chart_name
    chart_version  = var.chart_version
    release_name   = var.release_name
    namespace      = var.namespace
    update_trigger = var.trigger_helm_update != null ? var.trigger_helm_update : "initial"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting Helm install process..."
      
      # Create a temporary kubeconfig file
      KUBECONFIG_FILE=$(mktemp)
      echo "Created temporary KUBECONFIG file: $KUBECONFIG_FILE"
      
      # Write the kubeconfig content
      cat <<EOF > $KUBECONFIG_FILE
      apiVersion: v1
      kind: Config
      clusters:
      - cluster:
          server: ${var.cluster_endpoint}
          certificate-authority-data: ${var.cluster_ca_certificate}
        name: kubernetes
      contexts:
      - context:
          cluster: kubernetes
          user: aws
        name: aws
      current-context: aws
      users:
      - name: aws
        user:
          token: ${data.aws_eks_cluster_auth.cluster.token}
      EOF
      echo "Wrote kubeconfig content to $KUBECONFIG_FILE"
      
      # Create a temporary values file
      VALUES_FILE=$(mktemp)
      echo "Created temporary values file: $VALUES_FILE"
      
      # Write the values content
      cat <<EOF > $VALUES_FILE
      ${jsonencode(var.set_values)}
      EOF
      echo "Wrote values content to $VALUES_FILE"
      
      # Run Helm command with the temporary kubeconfig and values file
      echo "Running Helm command..."
      KUBECONFIG=$KUBECONFIG_FILE helm repo add ${var.repo_name} ${var.repo_url}
      KUBECONFIG=$KUBECONFIG_FILE helm repo update
      KUBECONFIG=$KUBECONFIG_FILE helm upgrade --install ${var.release_name} ${var.repo_name}/${var.chart_name} \
        --version ${var.chart_version} \
        --namespace ${var.namespace} \
        ${var.create_namespace ? "--create-namespace" : ""} \
        -f $VALUES_FILE \
        --debug
      
      HELM_EXIT_CODE=$?
      echo "Helm command exited with code: $HELM_EXIT_CODE"
      
      # Clean up the temporary files
      rm $KUBECONFIG_FILE
      rm $VALUES_FILE
      echo "Removed temporary KUBECONFIG and values files"
      
      exit $HELM_EXIT_CODE
    EOT
  }
}
