provider "aws" {
  region = "us-west-1"
}

# Network
resource "aws_vpc" "kubernetes_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "kubernetes-vpc"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "kubernetes_subnet" {
  vpc_id                  = aws_vpc.kubernetes_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0] # Use the first available zone as some zones may not support t3.small

  tags = {
    Name = "kubernetes"
  }
}

resource "aws_internet_gateway" "kubernetes_igw" {
  vpc_id = aws_vpc.kubernetes_vpc.id

  tags = {
    Name = "kubernetes"
  }
}

resource "aws_route_table" "kubernetes_route_table" {
  vpc_id = aws_vpc.kubernetes_vpc.id

  tags = {
    Name = "kubernetes"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.kubernetes_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.kubernetes_igw.id
}

resource "aws_route_table_association" "subnet_association" {
  subnet_id      = aws_subnet.kubernetes_subnet.id
  route_table_id = aws_route_table.kubernetes_route_table.id
}

# security groups
resource "aws_security_group" "kubernetes_security_group" {
  name        = "kubernetes"
  description = "Kubernetes security group"
  vpc_id      = aws_vpc.kubernetes_vpc.id

  tags = {
    Name = "kubernetes"
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group_rule" "allow_internal_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # Allow all protocols
  cidr_blocks       = ["10.0.0.0/16", "10.200.0.0/16"]
  security_group_id = aws_security_group.kubernetes_security_group.id
}

resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kubernetes_security_group.id
}

resource "aws_security_group_rule" "allow_api_server" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kubernetes_security_group.id
}

resource "aws_security_group_rule" "allow_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kubernetes_security_group.id
}

# resource "aws_security_group_rule" "allow_http" {
#   type              = "ingress"
#   from_port         = 80
#   to_port           = 80
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.kubernetes_security_group.id
# }

resource "aws_security_group_rule" "allow_icmp" {
  type              = "ingress"
  from_port         = -1 # ICMP traffic
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kubernetes_security_group.id
}

# generate SSH key
resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

resource "local_file" "ssh_public_key" {
  filename = pathexpand("../ansible/id_ed25519.pub")
  content  = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "ssh_private_key" {
  filename   = pathexpand("../ansible/id_ed25519")
  content    = tls_private_key.ssh_key.private_key_openssh
  file_permission = "0600" 
}

resource "aws_key_pair" "kubernetes_key_pair" {
  key_name   = "kubernetes"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Compute Instances
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name             = "name"
    values            = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name             = "root-device-type"
    values            = ["ebs"]
  }
  filter {
    name             = "architecture"
    values           = ["x86_64"]
  }
}

resource "aws_instance" "kubernetes_loadbalancer" {
  count               = 1
  ami                 = data.aws_ami.ubuntu.id
  instance_type       = "t3.micro"
  key_name            = aws_key_pair.kubernetes_key_pair.key_name
  subnet_id           = aws_subnet.kubernetes_subnet.id
  vpc_security_group_ids  = [aws_security_group.kubernetes_security_group.id]
  associate_public_ip_address = true
  private_ip          = "10.0.1.99"
  user_data           = <<-EOF
                        #!/bin/bash
                        name=kubernetes-loadbalancer
                        EOF
  tags = {
    Name = "kubernetes-loadbalancer"
  }

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
  }

  lifecycle {
    ignore_changes = [user_data]  # Avoid user data change trigger
  }
}

resource "aws_instance" "kubernetes_controller" {
  count               = 3  # Create 3 instances for Kubernetes controllers
  ami                 = data.aws_ami.ubuntu.id
  instance_type       = "t3.small"
  key_name            = aws_key_pair.kubernetes_key_pair.key_name
  subnet_id           = aws_subnet.kubernetes_subnet.id
  vpc_security_group_ids  = [aws_security_group.kubernetes_security_group.id]
  associate_public_ip_address = true
  private_ip          = "10.0.1.1${count.index}"
  user_data           = <<-EOF
                        #!/bin/bash
                        name=controller-${count.index}
                        EOF
  tags = {
    Name = "controller-${count.index}"
  }

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
  }

  lifecycle {
    ignore_changes = [user_data]  # Avoid user data change trigger
  }
}

resource "aws_instance" "kubernetes_worker" {
  count               = 3  # Create 3 instances for Kubernetes workers
  ami                 = data.aws_ami.ubuntu.id
  instance_type       = "t3.micro"
  key_name            = aws_key_pair.kubernetes_key_pair.key_name
  subnet_id           = aws_subnet.kubernetes_subnet.id
  vpc_security_group_ids  = [aws_security_group.kubernetes_security_group.id]
  associate_public_ip_address = true
  private_ip          = "10.0.1.2${count.index}"
  user_data           = <<-EOF
                        #!/bin/bash
                        name=worker-${count.index}
                        pod-cidr=10.200.${count.index}.0/24
                        EOF
  tags = {
    Name = "worker-${count.index}"
  }

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
  }

  lifecycle {
    ignore_changes = [user_data]  # Avoid user data change trigger
  }
}

# Outputs to capture instance IPs
output "kubernetes_controller_ips" {
  value = aws_instance.kubernetes_controller[*].public_ip
}

output "kubernetes_worker_ips" {
  value = aws_instance.kubernetes_worker[*].public_ip
}

output "kubernetes_loadbalancer_ips" {
  value = aws_instance.kubernetes_loadbalancer[*].public_ip
}

# Resource to generate Ansible inventory
resource "null_resource" "generate_inventory" {
  # Ensure this runs after instances are created
  depends_on = [
    aws_instance.kubernetes_controller,
    aws_instance.kubernetes_worker,
    aws_instance.kubernetes_loadbalancer
  ]

  triggers = {
    always_run = "${timestamp()}"  # Forces the resource to run on every apply
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "[loadbalancer]" > ../ansible/inventory
      echo "${join("\n", aws_instance.kubernetes_loadbalancer[*].public_ip)}" >> ../ansible/inventory

      echo "[masters]" >> ../ansible/inventory
      echo "${join("\n", aws_instance.kubernetes_controller[*].public_ip)}" >> ../ansible/inventory

      echo "[workers]" >> ../ansible/inventory
      echo "${join("\n", aws_instance.kubernetes_worker[*].public_ip)}" >> ../ansible/inventory
    EOT
  }
}

