locals {
  name = "docker-lab"
}

provider "aws" {
  region = "eu-west-2"
}

resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "keypair" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "kube-keypair.pem"
  file_permission = "600"
}

resource "aws_key_pair" "keypair" {
  key_name   = "kube-key"
  public_key = tls_private_key.keypair.public_key_openssh
}

resource "aws_security_group" "master-sg" {
  name        = "master-sg"
  description = "Allow specific inbound and outbound traffic"
    vpc_id      = "vpc-0179b941cefce91b2"

#allow specfic components for kube
  ingress {
    description = "Expose app on port 6443"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
   description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "etcd client communication"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "kube-schedular"
    from_port   = 10251
    to_port     = 10251
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "kube-controller-manager"
    from_port   = 10252
    to_port     = 10252
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "master-sg"
  }
}

resource "aws_security_group" "worker-sg" {
  name        = "worker-sg"
  description = "Inbound traffic for Maven server"
  vpc_id      = "vpc-0179b941cefce91b2"

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node Port services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Weave net"
    from_port   = 6783
    to_port     = 6784
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes read only port"
    from_port   = 10255
    to_port     = 10255
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "DNS Resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "VXLAN (Overlay network traffic)"
    from_port   = 4789
    to_port     = 4789
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "worker-sg"
  }
}

resource "aws_instance" "master" {
  ami                         = "ami-09dbc7ce74870d573" #ubuntu
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.master-sg.id]
  key_name                    = aws_key_pair.keypair.key_name
  subnet_id                   = "subnet-08b318f79785d7edd"
  associate_public_ip_address = true
  user_data                   = file("./master-userdata.sh")

  tags = {
    Name = "master-node"
  }
}

resource "aws_instance" "worker" {
  count =  2
  ami                         = "ami-09dbc7ce74870d573" #ubuntu
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.worker-sg.id]
  key_name                    = aws_key_pair.keypair.key_name
  subnet_id                   = "subnet-08b318f79785d7edd"
  associate_public_ip_address = true
  user_data                   = file("./worker-userdata.sh")

  tags = {
    Name = "worker-node-${count.index + 1}"
  }
}

output "master-ip" {
  value = aws_instance.master.public_ip
}

output "workers-ip" {
  value = aws_instance.worker.*.public_ip
}