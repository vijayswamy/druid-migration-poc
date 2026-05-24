terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.prefix}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    "kubernetes.io/cluster/${var.prefix}-eks" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"         = 1
    "kubernetes.io/cluster/${var.prefix}-eks" = "owned"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                  = 1
    "kubernetes.io/cluster/${var.prefix}-eks" = "owned"
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.prefix}-eks"
  cluster_version = "1.30"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # Disable KMS encryption for POC (avoids IAM permission issues on new accounts)
  create_kms_key          = false
  cluster_encryption_config = []

  eks_managed_node_groups = {
    default = {
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.medium"]

      iam_role_additional_policies = {
        s3_access = aws_iam_policy.druid_s3_access.arn
      }
    }
  }

  tags = {
    Environment = "poc"
    Project     = "druid-migration"
  }
}

# S3 Bucket — Druid deep storage
resource "aws_s3_bucket" "druid_deep_storage" {
  bucket        = "${var.prefix}-druid-segments"
  force_destroy = true

  tags = {
    Environment = "poc"
    Project     = "druid-migration"
  }
}

resource "aws_s3_bucket_ownership_controls" "druid_deep_storage" {
  bucket = aws_s3_bucket.druid_deep_storage.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# EBS CSI Driver addon — required for PVC provisioning on EKS
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  depends_on = [module.eks]
}

# Attach EBS CSI policy to node group role
resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = module.eks.eks_managed_node_groups["default"].iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# EKS Access Entry — grants the IAM user kubectl admin access
resource "aws_eks_access_entry" "admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.iam_username}"
  type          = "STANDARD"

  depends_on = [module.eks]
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

data "aws_caller_identity" "current" {}

# IAM Policy — allow EKS nodes to read/write Druid S3 bucket
resource "aws_iam_policy" "druid_s3_access" {
  name        = "${var.prefix}-druid-s3-access"
  description = "Allow Druid pods to access S3 deep storage"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.druid_deep_storage.arn,
          "${aws_s3_bucket.druid_deep_storage.arn}/*"
        ]
      }
    ]
  })
}
