data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}


resource "null_resource" "helm_install" {
  triggers = {
    chart_name          = var.chart_name
    chart_version       = var.chart_version
    release_name        = var.release_name
    namespace           = var.namespace
    trigger_helm_update = var.trigger_helm_update != false ? timestamp() : "initial"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting Helm install process..."
      
      # Create a temporary kubeconfig file
      export KUBECONFIG=$(mktemp)
      echo "Created temporary KUBECONFIG file: $KUBECONFIG"
      
      # Write the kubeconfig content
      cat <<EOF > $KUBECONFIG
      apiVersion: v1
      kind: Config
      clusters:
      - cluster:
          server: ${data.aws_eks_cluster.cluster.endpoint}
          certificate-authority-data: ${data.aws_eks_cluster.cluster.certificate_authority[0].data}
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
      echo "Wrote kubeconfig content to $KUBECONFIG"
      
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
      helm repo add ${var.repo_name} ${var.repo_url}
      helm repo update
      helm upgrade --install ${var.release_name} ${var.repo_name}/${var.chart_name} \
        --version ${var.chart_version} \
        --namespace ${var.namespace} \
        ${var.create_namespace ? "--create-namespace" : ""} \
        -f $VALUES_FILE \
        --debug
      
      HELM_EXIT_CODE=$?
      echo "Helm command exited with code: $HELM_EXIT_CODE"
      
      # Clean up the temporary files
      rm $KUBECONFIG
      rm $VALUES_FILE
      echo "Removed temporary KUBECONFIG and values files"
      
      exit $HELM_EXIT_CODE
    EOT
  }
}
