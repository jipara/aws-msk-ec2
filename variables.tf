variable "global_prefix" {
  type = string
  default = "my-own-apache-kafka-cluster"
}

variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}
