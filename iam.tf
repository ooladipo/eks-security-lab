# ==================================================
# EKS Cluster IAM Role
# ==================================================

resource "aws_iam_role" "eks_cluster" {
  name = "eks-security-lab-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "eks-security-lab-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


# ==================================================
# EKS Node IAM Role
# ==================================================

resource "aws_iam_role" "eks_node" {
  name = "eks-security-lab-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "eks-security-lab-node-role"
  }
}


# ==================================================
# EKS Node Policies
# ==================================================

resource "aws_iam_role_policy_attachment" "eks_node_worker_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# ==================================================
# Pod Identity - S3 Reader Policy
# ==================================================

resource "aws_iam_policy" "pod_s3_reader" {
  name        = "eks-security-lab-pod-s3-reader"
  description = "Allow EKS pod to read only the test S3 object"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = "${aws_s3_bucket.pod_identity_lab.arn}/test-object.txt"
      }
    ]
  })
}


# ==================================================
# Pod Identity IAM Role
# ==================================================

resource "aws_iam_role" "pod_s3_reader" {
  name = "eks-security-lab-pod-s3-reader"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "pods.eks.amazonaws.com"
        }

        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name = "eks-security-lab-pod-s3-reader"
  }
}


resource "aws_iam_role_policy_attachment" "pod_s3_reader" {
  role       = aws_iam_role.pod_s3_reader.name
  policy_arn = aws_iam_policy.pod_s3_reader.arn
}