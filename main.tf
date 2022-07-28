resource "aws_vpc" "rok_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "rok_public_subnet" {
  vpc_id                  = aws_vpc.rok_vpc.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "rok_internet_gateway" {
  vpc_id = aws_vpc.rok_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "rok_public_rt" {
  vpc_id = aws_vpc.rok_vpc.id

  tags = {
    Name = "dev-public_rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.rok_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.rok_internet_gateway.id
}

resource "aws_route_table_association" "rok_public_assoc" {
  subnet_id      = aws_subnet.rok_public_subnet.id
  route_table_id = aws_route_table.rok_public_rt.id
}


resource "aws_security_group" "rok_sg" {
  name        = "dev_sg"
  description = "dev security group"
  vpc_id      = aws_vpc.rok_vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["138.88.77.201/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "rok_auth" {
  key_name   = "rokkey"
  public_key = file("~/.ssh/trainingkey.pub")
}

resource "aws_instance" "dev_node" {
  ami                    = data.aws_ami.server_ami.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.rok_auth.id
  vpc_security_group_ids = [aws_security_group.rok_sg.id]
  subnet_id              = aws_subnet.rok_public_subnet.id
  user_data              = file("userdata.tpl")
  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }

  provisioner "local-exec" {
    command = templatefile("linux-mac-ssh-config.tpl", {
      hostname     = self.public_ip
      user         = "ubuntu"
      identityfile = "~/.ssh/trainingkey"
    })
    interpreter = ["/bin/bash", "-c"]
  }
}