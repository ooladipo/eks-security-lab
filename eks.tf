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