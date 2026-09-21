# ==========================================
# DATA BLOCKS
# ==========================================

# 1. Get available Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# 2. Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 3. Get current AWS account information
data "aws_caller_identity" "current" {}

# 4. Get current AWS region
data "aws_region" "current" {}


# ==========================================
# VPC
# ==========================================

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
    Project     = var.project_name
  }
}


# ==========================================
# INTERNET GATEWAY
# ==========================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
    Project     = var.project_name
  }
}


# ==========================================
# SUBNETS
# ==========================================

resource "aws_subnet" "main" {
  count = length(var.subnet_cidrs)

  vpc_id = aws_vpc.main.id

  cidr_block = var.subnet_cidrs[count.index]

  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-subnet-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
  }
}


# ==========================================
# ROUTE TABLE
# ==========================================

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-route-table"
    Environment = var.environment
    Project     = var.project_name
  }
}


# ==========================================
# ROUTE TABLE ASSOCIATIONS
# ==========================================

resource "aws_route_table_association" "main" {
  count = length(aws_subnet.main)

  subnet_id = aws_subnet.main[count.index].id

  route_table_id = aws_route_table.main.id
}


# ==========================================
# EC2 INSTANCES
# ==========================================

resource "aws_instance" "app" {
  count = var.instance_count

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.main[
    count.index % length(aws_subnet.main)
  ].id

  associate_public_ip_address = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
  }
}