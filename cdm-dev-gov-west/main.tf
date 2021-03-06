terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.54"
    }
  }
}

variable "env" {
  type    = string
  default = ""
}

variable "region" {
  type    = string
  default = ""
}

variable "role_partition_ids" {
  type = map(string)
  default = {
    "dev" : "434534557"
    "stage" : "43453456"
    "prod" : "434534543"
  }
}

output "role" {
  value = var.role_partition_ids[var.env]
}

variable "provision_region" {
  type = map(string)
  default = {
    "gov-west" = "us-gov-west-1"
    "gov-east" = "us-gov-east-1"
  }
  description = "Region to be used"
}

output "region" {
  value = var.provision_region[var.region]
}

provider "aws" {
  region     = var.provision_region[var.region]
  assume_role {
    role_arn     = "arn:aws-us-gov:iam::${var.role_partition_ids[var.env]}:role/CVLE_Administrator"
    session_name = "terraform"
  }
}

data "aws_vpc" "range_vpc" {
  filter {
    name = "tag:Name"
    values = [
      "RANGE-VPC"]
  }
}

data "aws_subnet" "vpc_range_subnet1" {
  filter {
    name = "tag:Name"
    values = [
      "RANGE-Private-Subnet-1"]
  }
}

output "vpc_range_subnet1" {
  value = data.aws_subnet.vpc_range_subnet1.cidr_block
}


locals {
  ami = "ami-0e8f77cbe14d2e912" # CDM ES4 lifecyle time range
  instance_type = "t3.large"
  environment = "dev-cdm"
  name        = "cdm-es4"
}


resource "aws_security_group" "range-cdm-sg" {
  vpc_id = data.aws_vpc.range_vpc.id
  name   = "RANGE-CDM-SG"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags = {
    "Name"        = "RANGE-CDM-SG"
    "Environment" = local.environment
  }
}



// Generated TF Below


resource "aws_instance" "ec2-cdm_100" {
  ami           = "ami-0e8f77cbe14d2e912"
  instance_type = "t3.large"
  tags = {
    Name        = "CDM_ES4_CEAC187612C34A89A9B605D039A05A43"
    Environment = "dev"
  }

  user_data = <<-EOF
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit

#!/bin/bash
idx=0
while [ "$( docker container inspect -f '{{.State.Health.Status}}' kib )" != "healthy" ]; do
  sleep 2;
  if (( idx > 600 )); then # 20 minutes.
    exit 1
  fi
  (( idx++ ))
done

if [ "$( docker container inspect -f '{{.State.Status}}' kib )" == "running" ]; then

  sed -i 's/\"@@@PARSEDURL@@@\", args.kibana/\"@@@PARSEDURL@@@\", \"https:\/\/dev-train.fooource-training.com\/web\/CEAC187612C34A89A9B605D039A05A43\"/' /var/lib/docker/overlay2/74b27f078db16b06e14bafc2b997408122c4ed6273c6a585ad3fe30a3b38f952/diff/apps/cdm/deploy.py
  sed -i 's/\"endpoint\", args.kibana/\"endpoint\", \"https:\/\/dev-train.fooource-training.com\/web\/CEAC187612C34A89A9B605D039A05A43\"/' /var/lib/docker/overlay2/74b27f078db16b06e14bafc2b997408122c4ed6273c6a585ad3fe30a3b38f952/diff/apps/cdm/deploy.py

  sed -i 's/\"180d\"/\"1000d\"/' /var/lib/docker/overlay2/74b27f078db16b06e14bafc2b997408122c4ed6273c6a585ad3fe30a3b38f952/diff/apps/cdm/ilms/cdm_delete_after_180_days.json
  sed -i 's/\"timepicker:timeDefaults\": \"{\\n  \\"from\\": \\"now-30d\\",\\n  \\"to\\": \\"now\\"\\n}\"}/"timepicker:timeDefaults\": \"{\\n  \\"from\\": \\"now-1y\\",\\n  \\"to\\": \\"now\\"\\n}\"}/' /var/lib/docker/overlay2/74b27f078db16b06e14bafc2b997408122c4ed6273c6a585ad3fe30a3b38f952/diff/apps/cdm/objects/cdm.ndjson

  cd /usr/local/share/cdm-dashboard/cdm-compose
  sudo -H -u ec2-user bash -c '/usr/local/bin/docker-compose -f cdm-docker-tls.yml down'
  sudo -H -u ec2-user bash -c '/usr/local/bin/docker-compose -f cdm-docker-installer-tls.yml up -d' # this takes 30 seconds
  sleep 61 # to allow time for the dashboard installer to complete
  sudo -H -u ec2-user bash -c '/usr/local/bin/docker-compose -f cdm-docker-installer-tls.yml down'
  sudo -H -u ec2-user bash -c '/usr/local/bin/docker-compose -f cdm-docker-tls.yml up -d' # this takes 30 seconds

  sleep 31 # to allow time for kibana and ES to startup

  docker exec es bash -c "echo \ >> ./config/jvm.options"
  docker exec es bash -c "echo '-Dlog4j2.formatMsgNoLookups=true' >> ./config/jvm.options"
  sudo -H -u ec2-user bash -c 'docker restart es' # this takes 30 seconds

  docker exec kib bash -c "echo \ >> ./config/kibana.yml"
  docker exec kib bash -c "echo 'server.publicBaseUrl: https://dev-train.fooource-training.com/web/CEAC187612C34A89A9B605D039A05A43' >> ./config/kibana.yml"
  docker exec kib bash -c "echo 'server.basePath: /web/CEAC187612C34A89A9B605D039A05A43' >> ./config/kibana.yml"
  docker exec kib bash -c "echo 'server.rewriteBasePath: true' >> ./config/kibana.yml"
  sudo -H -u ec2-user bash -c 'docker restart kib' # this takes 30 seconds
fi
 EOF

  network_interface {
    network_interface_id = aws_network_interface.ec2-cdm-ni_100.id
    device_index         = 0
  }
}

resource "aws_network_interface" "ec2-cdm-ni_100" {
  security_groups = [aws_security_group.range-cdm-sg.id]
  subnet_id = data.aws_subnet.vpc_range_subnet1.id
  private_ips = ["174.16.16.100"]
  tags = {
     Name        = "CDM_ES4_NI_CEAC187612C34A89A9B605D039A05A43"
     Environment = "dev"
  }
}






resource "aws_instance" "ec2-cdm_101" {
  ami           = "ami-0e8f77cbe14d2e912"
  instance_type = "t3.large"
  tags = {
    Name        = "CDM_ES4_7403CD4A02C442ADA1991D76B308A208"
    Environment = "dev"
  }

  user_data = <<-EOF
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit

#!/bin/bash
idx=0
while [ "$( docker container inspect -f '{{.State.Health.Status}}' kib )" != "healthy" ]; do
  sleep 2;
  if (( idx > 600 )); then # 20 minutes.
    exit 1
  fi
  (( idx++ ))
done

if [ "$( docker container inspect -f '{{.State.Status}}' kib )" == "running" ]; then

  sed -i 's/\"@@@PARSEDURL@@@\", args.kibana/\"@@@PARSEDURL@@@\", \"https:\/\/dev-train.fooource-training.com\/web\/7403CD4A02C442ADA1991D76B308A208\"/' /var/lib/docker/overlay2/74b27f078db16b06e14bafc2b997408122c4ed6273c6a585ad3fe30a3b38f952/diff/apps/cdm/deploy.py
  sed -i 's/\"endpoint\", args.kibana/\"endpoint\", \"https:\/\/dev-train.fooource-training.com\/web\/7403CD4A02C442ADA1991D76B308A208\"/' /var/lib/docker/overlay2/74b27f078db16b06e14bafc2b997408122c4ed6273c6a585ad3fe30a3b38f952/diff/apps/cdm/deploy.py

  sed -i 's/\"180d\"/\"1000d\"/' /var/lib/docker/overlay2/74b27f078db16b06e14bafc2b997408122c4ed6273c6a585ad3fe30a3b38f952/diff/apps/cdm/ilms/cdm_delete_after_180_days.json
  sed -i 's/\"timepicker:timeDefaults\": \"{\\n  \\"from\\": \\"now-30d\\",\\n  \\"to\\": \\"now\\"\\n}\"}/"timepicker:timeDefaults\": \"{\\n  \\"from\\": \\"now-1y\\",\\n  \\"to\\": \\"now\\"\\n}\"}/' /var/lib/docker/overlay2/74b27f078db16b06e14bafc2b997408122c4ed6273c6a585ad3fe30a3b38f952/diff/apps/cdm/objects/cdm.ndjson

  cd /usr/local/share/cdm-dashboard/cdm-compose
  sudo -H -u ec2-user bash -c '/usr/local/bin/docker-compose -f cdm-docker-tls.yml down'
  sudo -H -u ec2-user bash -c '/usr/local/bin/docker-compose -f cdm-docker-installer-tls.yml up -d' # this takes 30 seconds
  sleep 61 # to allow time for the dashboard installer to complete
  sudo -H -u ec2-user bash -c '/usr/local/bin/docker-compose -f cdm-docker-installer-tls.yml down'
  sudo -H -u ec2-user bash -c '/usr/local/bin/docker-compose -f cdm-docker-tls.yml up -d' # this takes 30 seconds

  sleep 31 # to allow time for kibana and ES to startup

  docker exec es bash -c "echo \ >> ./config/jvm.options"
  docker exec es bash -c "echo '-Dlog4j2.formatMsgNoLookups=true' >> ./config/jvm.options"
  sudo -H -u ec2-user bash -c 'docker restart es' # this takes 30 seconds

  docker exec kib bash -c "echo \ >> ./config/kibana.yml"
  docker exec kib bash -c "echo 'server.publicBaseUrl: https://dev-train.fooource-training.com/web/7403CD4A02C442ADA1991D76B308A208' >> ./config/kibana.yml"
  docker exec kib bash -c "echo 'server.basePath: /web/7403CD4A02C442ADA1991D76B308A208' >> ./config/kibana.yml"
  docker exec kib bash -c "echo 'server.rewriteBasePath: true' >> ./config/kibana.yml"
  sudo -H -u ec2-user bash -c 'docker restart kib' # this takes 30 seconds
fi
 EOF

  network_interface {
    network_interface_id = aws_network_interface.ec2-cdm-ni_101.id
    device_index         = 0
  }
}

resource "aws_network_interface" "ec2-cdm-ni_101" {
  security_groups = [aws_security_group.range-cdm-sg.id]
  subnet_id = data.aws_subnet.vpc_range_subnet1.id
  private_ips = ["174.16.16.101"]
  tags = {
     Name        = "CDM_ES4_NI_7403CD4A02C442ADA1991D76B308A208"
     Environment = "dev"
  }
}






