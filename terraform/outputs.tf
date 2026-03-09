output "security_group_id" {
  value = aws_security_group.boxes-sg.id
}

output "key_name" {
  value = aws_key_pair.boxes_key.key_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.boxes_ecr.repository_url
}

output "ec2_public_ip" {
  value = aws_instance.boxes_ec2.public_ip
}