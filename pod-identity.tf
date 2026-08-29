# ==================================================
# S3 Bucket for Pod Identity Lab
# ==================================================

resource "aws_s3_bucket" "pod_identity_lab" {
  bucket_prefix = "eks-security-lab-pod-identity-"

  tags = {
    Name = "eks-security-lab-pod-identity"
  }
}

resource "aws_s3_object" "pod_identity_test" {
  bucket = aws_s3_bucket.pod_identity_lab.id
  key    = "test-object.txt"
  source = "${path.module}/test-object.txt"

  etag = filemd5("${path.module}/test-object.txt")
}

# ==================================================
# EKS Pod Identity Association
# ==================================================

resource "aws_eks_pod_identity_association" "s3_reader" {
  cluster_name    = aws_eks_cluster.eks_lab.name
  namespace       = "network-policy-lab"
  service_account = "s3-reader"
  role_arn        = aws_iam_role.pod_s3_reader.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent
  ]
}