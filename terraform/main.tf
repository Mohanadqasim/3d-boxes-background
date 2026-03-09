resource "aws_security_group" "boxes-sg" {
  name        = "boxes-sg"
  description = "Allow SSH and TCP 5000"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TCP 5000 from anywhere"
    from_port   = 5000
    to_port     = 5000
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
    Name = "boxes-sg"
  }
}

resource "tls_private_key" "boxes_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "boxes_key" {
  key_name   = "boxes-key"
  public_key = tls_private_key.boxes_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.boxes_key.private_key_pem
  filename        = "${path.module}/boxes-key.pem"
  file_permission = "0400"
}

resource "aws_iam_role" "boxes_ec2_role" {
  name = "boxes-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecr_readonly_attach" {
  role       = aws_iam_role.boxes_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "boxes_instance_profile" {
  name = "boxes-instance-profile"
  role = aws_iam_role.boxes_ec2_role.name
}

resource "aws_ecr_repository" "boxes_ecr" {
  name                 = "boxes-ecr"
  force_delete         = true
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "boxes-ecr"
  }
}

resource "aws_instance" "boxes_ec2" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id = data.aws_subnet.default_subnet.id

  vpc_security_group_ids = [
    aws_security_group.boxes-sg.id
  ]

  key_name = aws_key_pair.boxes_key.key_name

  iam_instance_profile = aws_iam_instance_profile.boxes_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user
              EOF

  tags = {
    Name = "boxes-ec2"
  }
}