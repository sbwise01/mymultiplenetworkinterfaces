variable "environment" {
  default = "poc"
}

variable "subnet_id" {
  default = "subnet-b77e6bdf"
}

variable "instance_type" {
  default = "c5n.large"
}

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "bw-terraform-state-us-east-2"
    key    = "multiplenetworkinterfaces.tfstate"
    region = "us-east-2"
  }
}

data "aws_caller_identity" "current" {}

provider "aws" {
  region  = "us-east-2"
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_ami" "amzn2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [
    "137112412989" # Amazon
  ]
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [
    "099720109477" # Amazon
  ]
}


data "aws_ami" "ubuntuold" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu-minimal/images/hvm-ssd/ubuntu-xenial-16.04-amd64-minimal-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [
    "099720109477" # Amazon
  ]
}

resource "aws_network_interface" "vmwware_workstation_1_network_interface_2" {
  subnet_id         = var.subnet_id
  security_groups   = [aws_security_group.ec2_allow.id]
  source_dest_check = "false"
  private_ips       = ["172.31.11.129"]

  attachment {
    instance     = aws_instance.vmwware_workstation_1.id
    device_index = 1
  }
  tags = {
    Name       = "vmwware-workstation-1-interface-2-${var.environment}"
    Managed_by = "Terraform"
  }
}

# Amazon Linux automatically adds configuration for 2nd network interface
resource "aws_instance" "vmwware_workstation_1" {
  ami                    = data.aws_ami.amzn2.id
  iam_instance_profile   = aws_iam_instance_profile.vmwware_workstation.name
  instance_type          = var.instance_type
  key_name               = "bwise"
  vpc_security_group_ids = [aws_security_group.ec2_allow.id]
  subnet_id              = var.subnet_id
  private_ip             = "172.31.8.243"

  root_block_device {
    volume_size = "20"
    volume_type = "gp2"
  }

  tags = {
    Name = "vmware-workstation-1-${var.environment}"
  }
}

resource "aws_network_interface" "vmwware_workstation_2_network_interface_2" {
  subnet_id         = var.subnet_id
  security_groups   = [aws_security_group.ec2_allow.id]
  source_dest_check = "false"
  private_ips       = ["172.31.11.130"]

  attachment {
    instance     = aws_instance.vmwware_workstation_2.id
    device_index = 1
  }
  tags = {
    Name       = "vmwware-workstation-2-interface-2-${var.environment}"
    Managed_by = "Terraform"
  }
}

# Ubuntu 18.04 Linux requires netplan configuration (see 51-secondary.yaml for example)
## NOTE:  I have not found a correct combination of Ubuntu 18.04 or greater and netplan configuraiton that works properly
resource "aws_instance" "vmwware_workstation_2" {
  ami                    = data.aws_ami.ubuntu.id
  iam_instance_profile   = aws_iam_instance_profile.vmwware_workstation.name
  instance_type          = "c5n.metal"
  key_name               = "bwise"
  vpc_security_group_ids = [aws_security_group.ec2_allow.id]
  subnet_id              = var.subnet_id
  private_ip             = "172.31.8.244"

  root_block_device {
    volume_size = "2000"
    volume_type = "gp2"
  }

  tags = {
    Name = "vmware-workstation-2-${var.environment}"
  }
}

resource "aws_network_interface" "vmwware_workstation_3_network_interface_2" {
  subnet_id         = var.subnet_id
  security_groups   = [aws_security_group.ec2_allow.id]
  source_dest_check = "false"
  private_ips       = ["172.31.11.131"]

  attachment {
    instance     = aws_instance.vmwware_workstation_3.id
    device_index = 1
  }
  tags = {
    Name       = "vmwware-workstation-3-interface-2-${var.environment}"
    Managed_by = "Terraform"
  }
}

# Ubuntu 16.04 Linux requires adding interface definition (see 51-ens5.cfg)
resource "aws_instance" "vmwware_workstation_3" {
  ami                    = data.aws_ami.ubuntuold.id
  iam_instance_profile   = aws_iam_instance_profile.vmwware_workstation.name
  instance_type          = var.instance_type
  key_name               = "bwise"
  vpc_security_group_ids = [aws_security_group.ec2_allow.id]
  subnet_id              = var.subnet_id
  private_ip             = "172.31.8.245"

  root_block_device {
    volume_size = "20"
    volume_type = "gp2"
  }

  tags = {
    Name = "vmware-workstation-3-${var.environment}"
  }
}

resource "aws_security_group" "ec2_allow" {
  name   = "vmwware-workstation-ec2-ingress-allow-${var.environment}"
  vpc_id = data.aws_subnet.selected.vpc_id
}

resource "aws_security_group_rule" "ec2_ingress_instances_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["98.97.8.169/32"]
  description       = "Allow (port 443) traffic inbound to VMWare Workstation instance"
  security_group_id = aws_security_group.ec2_allow.id
}

resource "aws_security_group_rule" "ec2_ingress_instances_self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.ec2_allow.id
  description              = "Allow (port 443) traffic inbound to VMWare Workstation instance"
  security_group_id        = aws_security_group.ec2_allow.id
}

resource "aws_security_group_rule" "ec2_egress_instances_all" {
  type              = "egress"
  from_port         = "0"
  to_port           = "65535"
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from VMWare Workstation instance"
  security_group_id = aws_security_group.ec2_allow.id
}

resource "aws_iam_instance_profile" "vmwware_workstation" {
  name = "vmwware-workstation-${var.environment}"
  role = aws_iam_role.vmwware_workstation.name
}

resource "aws_iam_role" "vmwware_workstation" {
  name               = "vmwware-workstation-${var.environment}"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.vmwware_workstation_assume_role_policy.json
}

data "aws_iam_policy_document" "vmwware_workstation_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "vmwware_workstation_policy" {
  name   = "vmwware-workstation-policy-${var.environment}"
  role   = aws_iam_role.vmwware_workstation.id
  policy = data.aws_iam_policy_document.vmwware_workstation_policy.json
}

data "aws_iam_policy_document" "vmwware_workstation_policy" {
  statement {
    actions = ["s3:*"]
    resources = ["*"]
  }
}
