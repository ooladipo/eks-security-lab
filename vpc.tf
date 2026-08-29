# --------------------------------------------------
# VPC
# --------------------------------------------------

resource "aws_vpc" "eks_lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "eks-security-lab-vpc"
  }
}

# --------------------------------------------------
# Internet Gateway
# --------------------------------------------------

resource "aws_internet_gateway" "eks_lab" {
  vpc_id = aws_vpc.eks_lab.id

  tags = {
    Name = "eks-security-lab-igw"
  }
}

# --------------------------------------------------
# Public Subnets
# --------------------------------------------------

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.eks_lab.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "eks-security-lab-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"

  }
}

# --------------------------------------------------
# Private Subnets
# --------------------------------------------------

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.eks_lab.id
  cidr_block        = "10.0.${count.index + 11}.0/24"
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                              = "eks-security-lab-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"

  }
}

# --------------------------------------------------
# Public Route Table
# --------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks_lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_lab.id
  }

  tags = {
    Name = "eks-security-lab-public-rt"
  }
}

# --------------------------------------------------
# Public Route Table Associations
# --------------------------------------------------

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}