#!/bin/bash

# Variables de configuración
vpc_cidr_block="10.0.0.0/16"
public_subnet_cidr_blocks=("10.0.1.0/24" "10.0.2.0/24" "10.0.3.0/24")
private_subnet_cidr_blocks=("10.0.4.0/24" "10.0.5.0/24" "10.0.6.0/24")
availability_zones=("us-east-1a" "us-east-1b" "us-east-1c")

client_key="client"
client_value="abc"
env_key="env"
env_value="dev"

# Crear la VPC
vpc_id=$(aws ec2 create-vpc --cidr-block $vpc_cidr_block --output text --query 'Vpc.VpcId')
echo "VPC creada con ID: $vpc_id"

# Obtener la tabla de ruteo por defecto
rt_default_id=$(aws ec2 describe-route-tables --filter "Name=vpc-id,Values=${vpc_id}" --query "RouteTables[?Associations.Main == true].RouteTableId" --output text)


# Etiquetar la VPC
aws ec2 create-tags --resources $vpc_id --tags Key=Name,Value=MiVPC2 Key=$client_key,Value=$client_value Key=$env_key,Value=$env_value
echo "Etiquetas aplicadas a la VPC"

# Habilitar DNS en la VPC
aws ec2 modify-vpc-attribute --vpc-id $vpc_id --enable-dns-support "{\"Value\":true}"
aws ec2 modify-vpc-attribute --vpc-id $vpc_id --enable-dns-hostnames "{\"Value\":true}"
echo "Habilitado DNS en la VPC"

# Crear las subredes públicas
for ((i=0; i<${#public_subnet_cidr_blocks[@]}; i++)); do
  subnet_cidr=${public_subnet_cidr_blocks[i]}
  availability_zone=${availability_zones[i]}
  subnet_name="Pub-${subnet_cidr}-${availability_zone}"
  subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $subnet_cidr --availability-zone $availability_zone --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value='$subnet_name'},{Key='$client_key',Value='$client_value'},{Key='$env_key',Value='$env_value'}]' --output text --query 'Subnet.SubnetId')
	echo "Subred creada con ID: $subnet_id y nombre: $subnet_name"

  # Asociar la subred a la tabla de ruteo principal
  aws ec2 associate-route-table --subnet-id $subnet_id --route-table-id $rt_default_id
  echo "Subred pública asociada a la tabla de ruteo principal"
done

#Creamos el internet gateway
igw_id=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
echo "Internet gateway creado con ID: $igw_id"

aws ec2 create-tags --resources $igw_id --tags Key=Name,Value=igw-curso Key=$client_key,Value=$client_value Key=$env_key,Value=$env_value
echo "Etiquetas aplicadas a el igw"

# Se asocia el igw a la VPC
aws ec2 attach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id

# Crear una ruta de Internet Gateway hacia la tabla de ruteo principal
#igw_id=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[0].InternetGatewayId' --output text)
aws ec2 create-route --route-table-id $rt_default_id --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id
echo "Ruta de Internet Gateway creada en la tabla de ruteo principal"

# Crear las subredes privadas

for ((i=0; i<${#private_subnet_cidr_blocks[@]}; i++)); do
  subnet_cidr=${private_subnet_cidr_blocks[i]}
  availability_zone=${availability_zones[i]}
  subnet_name="Priv-${subnet_cidr}-${availability_zone}"

  subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $subnet_cidr --availability-zone $availability_zone --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value='$subnet_name'},{Key='$client_key',Value='$client_value'},{Key='$env_key',Value='$env_value'}]' --output text --query 'Subnet.SubnetId')
	echo "Subred creada con ID: $subnet_id y nombre: $subnet_name"

  # Crear una tabla de ruteo privada
  route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --output text --query 'RouteTable.RouteTableId')
  echo "Tabla de ruteo privada creada con ID: $route_table_id"

  # Asociar la subred a la tabla de ruteo privada
  aws ec2 associate-route-table --subnet-id $subnet_id --route-table-id $route_table_id
  echo "Subred privada asociada a la tabla de ruteo privada"

done

echo "¡Configuración completada!"

