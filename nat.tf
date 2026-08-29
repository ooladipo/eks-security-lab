# ==================================================
# NAT Gateway
# ==================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "eks-security-lab-nat-eip"
  }
}

resource "aws_nat_gateway" "eks_lab" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "eks-security-lab-nat"
  }

  depends_on = [
    aws_internet_gateway.eks_lab
  ]
}


# ==================================================
# Private Route Table
# ==================================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.eks_lab.id

  tags = {
    Name = "eks-security-lab-private-rt"
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.eks_lab.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}