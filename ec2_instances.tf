/// DESPLEIGUE  DE los ec2S Y SUS sg's
/// DESPLEIGUE  DE los ec2S Y SUS sg's

// El "Bastion" debe tner un INBOOUND que permita SSH a si mismo desde my_ip, y OUTBOUND  que permita trafico de todo tipo al "PRIVATE"
// el PRIVATE debe tener un INBOOUND que permita SSH a si mismo desde el security group del BASTION, 
// y OUTBOUND que permita trafico de todo tipo al sec-group "MSK"
// el MSK debe tener un INBOUND que permita trafico de TODO tipo desde el SG del "PRIVATE"
// y un OUTBOUND que permita tráfico al LAMBDA?



# Define variables LLAVES (KEYPARIS)
variable "key_name" {
  description = "Name of the existing key pair"
  default     = "kp_iac_lab"  # Update with your existing key pair name
}

variable "key_name_2" {
  description = "Name of the existing key pair"
  default     = "labo_emr"  # Update with your existing key pair name
}




# Define Security Groups
resource "aws_security_group" "sg2" {
  name        = "SG-2"
  description = "Security Group allowing SSH traffic from SG-1 and all traffic from msk-sg-demo2"

  vpc_id      = data.aws_vpc.existing_vpc.id
  
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg1.id]  # Allow SSH traffic from SG-1
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}



resource "aws_security_group" "sg1" {
  name        = "SG-1"
  description = "Security Group allowing SSH traffic from the internet"

  vpc_id      = data.aws_vpc.existing_vpc.id

  ingress { 
    from_port   = 22                # Allow SSH traffic from the itnernet
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow outbound to everywhre
  }
  
}




/// INSTANCIAS
resource "aws_instance" "instance_1" {
  ami           = "ami-07caf09b362be10b8"  # Update with your desired AMI ID
  instance_type = "t2.micro"                # Update with your desired instance type
  key_name      = var.key_name
  vpc_security_group_ids  = [aws_security_group.sg1.id]
  
  subnet_id     =  data.aws_subnet.public_subnets.id # Specify the ID of your desired subnet

  associate_public_ip_address = true ### Este es el publico asi que si
  
  tags = {
    Name = "bastion"
  }
}

resource "aws_instance" "instance_2" {
  ami           = "ami-07caf09b362be10b8"  # Update with your desired AMI ID
  instance_type = "t2.micro"                # Update with your desired instance type
  key_name      = var.key_name_2
  vpc_security_group_ids  = [aws_security_group.sg2.id]
  
  subnet_id     =   data.aws_subnet.private_subnet_1.id

  associate_public_ip_address = false

  tags = {
    Name = "msk_app"
  }

  ### SUAR ASNIBLE PARA EL USER_DATA (HACER INSTALACIONES DESCARGAS)
  user_data = <<-EOF
              #!/bin/bash
              sudo yum install -y java-1.8.0-amazon-corretto wget
              wget https://archive.apache.org/dist/kafka/2.8.1/kafka_2.12-2.8.1.tgz
              tar -xvf kafka_2.12-2.8.1.tgz
              # Add any additional setup or configuration steps here
              EOF
}



