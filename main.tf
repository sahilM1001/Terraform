provider "aws" {
  region = "us-east-1"

}

#1 Creating a VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

#2 Creating internet gateway
resource "aws_internet_gateway" "gateway-1" {
  vpc_id = aws_vpc.prod-vpc.id
  
}

#3 Creating Custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway-1.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gateway-1.id
  }

  tags = {
    Name = "prod"
  }
  
}

#4 Create a Subnet
resource "aws_subnet" "prod-subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Prod-subnet"
  }
}

#5 Associate Route table with subnet
resource "aws_route_table_association" "r1" {
  subnet_id = aws_subnet.prod-subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
  
}

#6 Creating security group to allow traffic to port 22, 80, 443
resource "aws_security_group" "prod-security-group" {
  name = "allow_web_traffic"
  description = "Production security group to allow web traffic"
  vpc_id = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name ="Allow Web "
  }
}

#7 Creating network interface

resource "aws_network_interface" "web-server-nic" {
  subnet_id = aws_subnet.prod-subnet-1.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.prod-security-group.id]
  
}

#8 Assigning Elastic IP to the nic
resource "aws_eip" "one" {
  vpc = true
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gateway-1, aws_instance.prod-web-server]
}

resource "aws_instance" "prod-web-server" {
  ami = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "sahil-terraform-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
    
  }

  user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo Your first production server is live > /var/www/html/index.html'
            EOF

  tags = {
    Name = "Prod-web-server"
  }
}
