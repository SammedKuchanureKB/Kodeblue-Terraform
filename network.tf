provider "aws" { 
    profile = "sammed"
  region = "ap-south-2"
}

resource "aws_vpc" "KB_VPC" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "KB_SVPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "KB_igw" {
  vpc_id = aws_vpc.KB_VPC.id
  tags = {
    Name = "KB_igw"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnets" {
  count                   = 3
  vpc_id                  = aws_vpc.KB_VPC.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "KB_Public_Subnet_${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnets" {
  count                   = 3
  vpc_id                  = aws_vpc.KB_VPC.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index + 3)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "KB_Private_Subnet_${count.index + 1}"
  }
}

# NAT Gateway
resource "aws_eip" "NAT_eip" {
  domain = "vpc"
  tags = {
    Name = "NAT_eip"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.NAT_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id
  tags = {
    Name = "KB_nat_gw"
  }
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.KB_VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.KB_igw.id
  }
  tags = {
    Name = "KB_public_rt"
  }
}

resource "aws_route_table" "private_rts" {
  count  = 3
  vpc_id = aws_vpc.KB_VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "KB_private_rt_${count.index + 1}"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_associations" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_associations" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rts[count.index].id
}

# VPC Endpoint
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = aws_vpc.KB_VPC.id
  service_name = "com.amazonaws.ap-south-2.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = aws_route_table.private_rts[*].id
  tags = {
    Name = "S3-VPC-Endpoint"
  }
}

# Data Source for Availability Zones
data "aws_availability_zones" "available" {}
