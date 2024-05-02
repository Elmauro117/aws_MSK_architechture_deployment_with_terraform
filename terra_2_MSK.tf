
data "aws_vpc" "existing_vpc" {
  tags = {
    Name = "VPC_kafka_lambda_lab"  # Replace "YourVPCName" with the actual name of your VPC
  }
}

data "aws_subnet" "private_subnet_1" {
  filter {
    name   = "tag:Name"
    values = ["Private-Subnet-A-lambda"]  
  }
}

data "aws_subnet" "private_subnet_2" {
  filter {
    name   = "tag:Name"
    values = ["Private-Subnet-B-lambda"]  
  }
}


data "aws_subnet" "public_subnets" {
  vpc_id = data.aws_vpc.existing_vpc.id
  filter {
    name   = "tag:Name"
    values = ["Public_A_subnet"]  
  }
}

resource "aws_security_group" "sg" {
  name        = "msk-sg-demo2"
  description = "Security Group for MSK Cluster"
  vpc_id      = data.aws_vpc.existing_vpc.id
  
  // Permitimos tráfico de si mismo
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self = true
  }
  
}



// Crear el MSK CLUSTER
resource "aws_msk_configuration" "config" {
  kafka_versions    = ["2.8.1"]
  name              = "msk-configuration"
  server_properties = <<-PROPERTIES
    auto.create.topics.enable = true
    delete.topic.enable = true
  PROPERTIES
}

resource "aws_msk_cluster" "cluster" {
  cluster_name = "msk-cluster"
  kafka_version = "2.8.1"
  number_of_broker_nodes = 2
  
  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    client_subnets  = [data.aws_subnet.private_subnet_1.id, 
                        data.aws_subnet.private_subnet_2.id]
    security_groups = [aws_security_group.sg.id]
    storage_info {
      ebs_storage_info {
        volume_size = 2
      }
    }
  }
  /// encirptado PLAINTEXT
  encryption_info {
    encryption_in_transit  {
      client_broker = "PLAINTEXT"
      in_cluster = false
    }
  }
  /// acces control methods
  client_authentication {
    //tls {
    //  certificate_authority_arns = local.pca_arn
    //}
    //sasl {
    //  iam = false
    //}
    unauthenticated = true
  }

  tags = {
    //Environment = "dev"
    Name        = "MSK Cluster"
  }
}


output "msk_id" {
  value = aws_msk_cluster.cluster.id
}







