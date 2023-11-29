# Add a s3 bucket backend, so that we can sync terraform state
terraform {
  backend "s3" {
    bucket         = "terraform-state-infc"
    key            = "state/terraform.tfstate"   # Path in the bucket
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}

# Specify the AWS provider with your region and AWS credentials
provider "aws" {
  region = "us-east-1"
  # Add your AWS access key and secret key here.
}


# Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Terraform Workshop"
  }
}


# Create Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "Terraform Workshop"
  }
}


# Create Custom Route Table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "Terraform Workshop"
  }
}

# Create Subnet
resource "aws_subnet" "my_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a" # Adjust the availability zone accordingly
  map_public_ip_on_launch = true
  tags = {
    Name = "Terraform Workshop"
  }
}

resource "aws_subnet" "my_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b" # Make sure this is different from the first subnet
  map_public_ip_on_launch = true
  tags = {
    Name = "Terraform Workshop"
  }
}

# Associate the new route table to our VPC, instead of using the default one
resource "aws_main_route_table_association" "my_main_route_table_association" {
  vpc_id          = aws_vpc.my_vpc.id
  route_table_id  = aws_route_table.my_route_table.id
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "my_route_table_association" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_route_table_association" "my_route_table_association_2" {
  subnet_id      = aws_subnet.my_subnet_2.id
  route_table_id = aws_route_table.my_route_table.id
}


# Create a security group
resource "aws_security_group" "web_server-sg" {
  name        = "web-server-sg"
  description = "Security group for the web server"
  vpc_id      = aws_vpc.my_vpc.id
  tags = {
    Name = "Terraform Workshop"
  }
 
  # Allow incoming traffic on port 80 (HTTP)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # Allow outgoing traffic to all destinations
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Multiple EC2 Instances
variable "instance_count" {
  description = "Number of instances to create"
  default     = 2
}

resource "aws_instance" "web_server" {
  count                  = var.instance_count
  ami                    = "ami-0fc5d935ebf8bc3bc"
  instance_type          = "t2.micro"
  associate_public_ip_address = true
  tags = {
    Name = "Terraform Workshop"
  }
  subnet_id = count.index % 2 == 0 ? aws_subnet.my_subnet.id : aws_subnet.my_subnet_2.id

  user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update
                sudo apt-get install -y apache2
                sudo systemctl start apache2
                sudo systemctl enable apache2
                echo "<h1>Hello from Instance ${count.index}</h1>" | sudo tee /var/www/html/index.html
                EOF

  vpc_security_group_ids = [aws_security_group.web_server-sg.id]
}
/*
# Create Application Load Balancer
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_server-sg.id]
  subnets            = [aws_subnet.my_subnet.id, aws_subnet.my_subnet_2.id] # Include both subnets
  tags = {
    Name = "Terraform Workshop"
  }
}

# Target Group for Load Balancer
resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
}

# Register Targets
resource "aws_lb_target_group_attachment" "web_tg_attachment" {
  count            = var.instance_count
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = element(aws_instance.web_server.*.id, count.index)
  port             = 80
}

# Listener for Load Balancer
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

output "lb_dns" {
  value = aws_lb.web_lb.dns_name
}
*/
# Output the public DNS addresses of the instances
output "public_dns" {
  value = [for instance in aws_instance.web_server : instance.public_dns]
}