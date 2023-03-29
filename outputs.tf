output "execute_this_to_access_the_bastion_host" {
    value = "ssh ec2-user@${aws_instance.bastion_host.public_ip} -i cert.pem"
}

output "vpc_id" {
  value = aws_vpc.your_vpc.id
}
