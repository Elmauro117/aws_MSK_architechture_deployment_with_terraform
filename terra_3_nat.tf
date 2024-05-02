
// importar el  IGW
data "aws_internet_gateway" "igw_vpc_msk" {
  internet_gateway_id = "xxxxxxxxxxxxxxxxxxxxx"
}
//crea el Ellastic IP
/*
resource "aws_eip" "ei_ngw" {
  instance = data.aws_vpc.existing_vpc.id
  //domain   = "vpc"
}
*/
resource "aws_eip" "ei_ngw" {
  vpc      = true  # Indicate that the EIP is for use in a VPC
}
//crea el Nat con el EIP alocado en el
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.ei_ngw.id    // le colocamos el Ellastic IP
  subnet_id     = data.aws_subnet.public_subnets.id 

  tags = {
    Name = "gw-NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [data.aws_internet_gateway.igw_vpc_msk]
}
//Route_tables
data "aws_route_table" "route_NAT" {
  route_table_id = "XXXXXXXXXXXXXXXX"
}
  
resource "aws_route" "nat_gateway_route" {
  route_table_id         = data.aws_route_table.route_NAT.id  # Replace with the ID of your existing private route table
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw.id  # Replace with the ID of your NAT Gateway
}

