# ==================================================
# EKS Cluster
# ==================================================

resource "aws_eks_cluster" "eks_lab" {
  name     = "eks-security-lab"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.36"

  vpc_config {
    subnet_ids = [
      aws_subnet.private[0].id,
      aws_subnet.private[1].id
    ]

    endpoint_private_access = true
    endpoint_public_access  = true

    public_access_cidrs = [
      "${var.admin_public_ip}/32"
    ]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator"
  ]

  upgrade_policy {
    support_type = "STANDARD"
  }

  tags = {
    Name = "eks-security-lab"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# ==================================================
# EKS Pod Identity Agent
# ==================================================

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.eks_lab.name
  addon_name   = "eks-pod-identity-agent"

  addon_version = "v1.4.0-eksbuild.1"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.eks_lab
  ]
}
