# ==================================================
# EKS Managed Node Group
# ==================================================

resource "aws_eks_node_group" "eks_lab" {
  cluster_name    = aws_eks_cluster.eks_lab.name
  node_group_name = "eks-security-lab-nodes"
  node_role_arn   = aws_iam_role.eks_node.arn

  subnet_ids = aws_subnet.private[*].id

  instance_types = ["t3.small"]

  capacity_type = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    Environment = "lab"
    NodeGroup   = "default"
  }

  tags = {
    Name = "eks-security-lab-node"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker_policy,
    aws_iam_role_policy_attachment.eks_node_cni_policy,
    aws_iam_role_policy_attachment.eks_node_ecr_policy
  ]
}