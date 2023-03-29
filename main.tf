resource "aws_vpc" "your_vpc" {
  cidr_block = var.vpc_cidr_block
}

resource "aws_kms_key" "kafka_kms_key" {
  description = "Key for Apache Kafka"
}

resource "aws_msk_configuration" "kafka_config" {
  kafka_versions = ["2.6.2"]
  name = "${var.global_prefix}-config"
  server_properties = <<EOF
auto.create.topics.enable = true
delete.topic.enable = true
EOF
}

# resource "aws_security_group" "kafka" {
#   name = "${var.global_prefix}-kafka"
#   vpc_id = aws_vpc.your_vpc.id
#   ingress {
#     from_port = 0
#     to_port = 9092
#     protocol = "TCP"
#     cidr_blocks = ["10.0.1.0/24",
#                   "10.0.2.0/24",
#                   "10.0.3.0/24"]
#   }
#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = {
#     Name = "${var.global_prefix}-kafka"
#   }
# }


resource "aws_msk_cluster" "kafka" {
  cluster_name = var.global_prefix
  kafka_version = "2.6.2"
  number_of_broker_nodes = 3
  broker_node_group_info {
    instance_type = "kafka.t3.small"
    storage_info {
      ebs_storage_info {
        volume_size = 1000
      }      
    }
    client_subnets = [aws_subnet.private_subnet[0].id,
                      aws_subnet.private_subnet[1].id,
                      aws_subnet.private_subnet[2].id]
    security_groups = [aws_security_group.kafka.id]
  }
  encryption_info {
    encryption_in_transit {
      client_broker = "PLAINTEXT"
    }
    encryption_at_rest_kms_key_arn = aws_kms_key.kafka_kms_key.arn
  }
  configuration_info {
    arn = aws_msk_configuration.kafka_config.arn
    revision = aws_msk_configuration.kafka_config.latest_revision
  }
  // Support for logging
  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled = true
        log_group = aws_cloudwatch_log_group.kafka_log_group.name
      }
    }
  }
  tags = {
    name = var.global_prefix
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

variable "private_cidr_blocks" {
  type = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
  ]
}

resource "aws_subnet" "private_subnet" {
  count = 3
  vpc_id = aws_vpc.your_vpc.id
  cidr_block = element(var.private_cidr_blocks, count.index)
  map_public_ip_on_launch = false
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.global_prefix}-private-subnet-${count.index}"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.your_vpc.id
  tags = {
    Name = "${var.global_prefix}-private-route-table"
  }
}

resource "aws_route_table_association" "private_subnet_association" {
  count = length(data.aws_availability_zones.available.names)
  subnet_id = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private_route_table.id
}


resource "aws_cloudwatch_log_group" "kafka_log_group" {
  name = "kafka_broker_logs"
}
