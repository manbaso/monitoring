
resource "aws_iam_instance_profile" "monitoring" {
  name = "monitoring-instance-profile"
  role = aws_iam_role.monitoring.name
}

resource "aws_iam_role" "monitoring" {
  name               = "ec2-log-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "monitoring" {
  name        = "ec2-log-ssm-policy"
  description = "Policy for EC2 to write logs and perform SSM operations"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "cloudwatch:PutMetricData",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommands",
          "ec2:*"
        ],
        Resource  = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = aws_iam_policy.monitoring.arn
}



resource "aws_cloudwatch_log_group" "monitoring" {
  for_each = var.log_stream
  name = each.key
  # tags = each.value
}

resource "aws_cloudwatch_log_stream" "monitoring" {
   
  for_each = var.log_stream

  name           = each.value
  log_group_name = aws_cloudwatch_log_group.monitoring[each.key].name
}

# Create VPC
resource "aws_vpc" "monitoring" {
  cidr_block = "10.0.0.0/16"
}

# Create internet gateway
resource "aws_internet_gateway" "monitoring" {
  vpc_id = aws_vpc.monitoring.id
}

# Create public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.monitoring.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Create private subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.monitoring.id
  cidr_block = "10.0.2.0/24"
}

# Create route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.monitoring.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.monitoring.id
  }
}

# Associate public subnet with public route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create security group for EC2 instance
resource "aws_security_group" "monitoring" {
  vpc_id = aws_vpc.monitoring.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9080
    to_port     = 9080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "monitoring_dev" {
  vpc_id = aws_vpc.monitoring.id
  name        = "MyAppSecurityGroup"
  description = "Security group for Jenkins, Prometheus, SonarQube, and Promtail"

  // Ingress rules
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Update with specific IP ranges if needed
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9080
    to_port     = 9080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9030
    to_port     = 9030
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Egress rules
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["10.0.1.0/24"]
    prefix_list_ids = []
  }

  // Egress rules
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["10.0.1.0/24"]
    prefix_list_ids = []
  }

  // Egress rules
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
}

# Launch EC2 instance
resource "aws_instance" "monitoring" {

  for_each = {
    "jenkins" = { vm_size = "t2.medium", private_ips="10.0.1.10" }
    "monitoring" = { vm_size = "t2.medium", private_ips="10.0.1.11" }
    "dev" = { vm_size = "t2.medium", private_ips="10.0.1.12"}
    "prod" = { vm_size = "t2.medium", private_ips="10.0.1.13"}
    # "nfs-server" = {vm_size = "t2.micro", private_ips="10.0.1.14"}

  }
  ami             = var.ami_id # Change to your desired AMI
  instance_type   = each.value.vm_size
  subnet_id       = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.monitoring_dev.id]
  key_name        = "project" # Change to your key pair name
  iam_instance_profile   = aws_iam_instance_profile.monitoring.name
  private_ip = each.value.private_ips
  associate_public_ip_address = true
 

  tags = {
     Name = each.key
  }
}




