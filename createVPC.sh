 #!/bin/sh

set -e

VPCNAME="$1"

echo "Starting Process of Creating VPC With Name $VPCNAME" 

VPCID=$(aws ec2 create-vpc --cidr-block 10.1.0.0/16 --instance-tenancy default|grep VpcId| awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')                                                          
echo "VPC with ID $VPCID Created"

aws ec2 create-tags --resources $VPCID  --tags Key=Name,Value=$VPCNAME


PUBLIC_SUBNET_1=$(aws ec2 create-subnet --availability-zone us-east-1a --vpc-id $VPCID --cidr-block 10.1.1.0/24|grep SubnetId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')
aws ec2 create-tags --resources $PUBLIC_SUBNET_1  --tags Key=Name,Value="$VPCNAME"_PUBLIC_SUBNET_1

echo "Public subnet 1 was created with ID = $PUBLIC_SUBNET_1 "

PRIVATE_SUBNET_1=$(aws ec2 create-subnet --availability-zone us-east-1a --vpc-id $VPCID --cidr-block 10.1.101.0/24|grep SubnetId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')
aws ec2 create-tags --resources $PRIVATE_SUBNET_1  --tags Key=Name,Value="$VPCNAME"_PRIVATE_SUBNET_1

echo "Private subnet 1 was created with ID = $PRIVATE_SUBNET_1 "

PUBLIC_SUBNET_2=$(aws ec2 create-subnet --availability-zone us-east-1c --vpc-id $VPCID --cidr-block 10.1.2.0/24|grep SubnetId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')
aws ec2 create-tags --resources $PUBLIC_SUBNET_2  --tags Key=Name,Value="$VPCNAME"_PUBLIC_SUBNET_2

echo "Public subnet 2 was created with ID = $PUBLIC_SUBNET_2 "

PRIVATE_SUBNET_2=$(aws ec2 create-subnet --availability-zone us-east-1c --vpc-id $VPCID --cidr-block 10.1.102.0/24|grep SubnetId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')
aws ec2 create-tags --resources $PRIVATE_SUBNET_2  --tags Key=Name,Value="$VPCNAME"_PRIVATE_SUBNET_2

echo "Private subnet 2 was created with ID = $PRIVATE_SUBNET_2 "

INTERNET_GATEWAY=$(aws ec2 create-internet-gateway | grep InternetGatewayId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')
aws ec2 create-tags --resources $INTERNET_GATEWAY  --tags Key=Name,Value="$VPCNAME"_INTERNET_GATEWAY

aws ec2 create-tags --resources $VPCID $PUBLIC_SUBNET_1 $PRIVATE_SUBNET_1 $PUBLIC_SUBNET_2 $PRIVATE_SUBNET_2 $INTERNET_GATEWAY --tags Key=Stack,Value=$VPCNAME


aws ec2 attach-internet-gateway --internet-gateway-id $INTERNET_GATEWAY --vpc-id $VPCID


echo "creating route table"

RT_PUB_SUB=$(aws ec2 create-route-table --vpc-id $VPCID | grep RouteTableId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')
#aws ec2 create-tags --resources $RT_PUB_SUB  --tags Key=Name,Value="$VPCNAME"_TO_INTERNET_GW


echo "creating route to internet gateway"

aws ec2 create-route --route-table-id $RT_PUB_SUB --destination-cidr-block 0.0.0.0/0 --gateway-id $INTERNET_GATEWAY

echo "assciating public subnet 1 with to gatway routing table"
echo "aws ec2 associate-route-table --route-table-id $RT_PUB_SUB --subnet-id $PUBLIC_SUBNET_1"
aws ec2 associate-route-table --route-table-id $RT_PUB_SUB --subnet-id $PUBLIC_SUBNET_1

echo "assciating public subnet 2 with to gatway routing table"
echo "aws ec2 associate-route-table --route-table-id $RT_PUB_SUB --subnet-id $PUBLIC_SUBNET_2"
aws ec2 associate-route-table --route-table-id $RT_PUB_SUB --subnet-id $PUBLIC_SUBNET_2


echo "Allocating public ip Address for NAT FOR PRIVATE SUBNET 1"
NAT_ALLOCATION1=$(aws ec2 allocate-address --domain vpc|grep AllocationId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')
#aws ec2 create-tags --resources $NAT_ALLOCATION1  --tags Key=Name,Value="$VPCNAME"_NAT1_ALLOCATION

echo "Allocating public ip Address for NAT FOR PRIVATE SUBNET 2"
NAT_ALLOCATION2=$(aws ec2 allocate-address --domain vpc|grep AllocationId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')


echo "creating route tables"

RT_PRIVATE_SUB1=$(aws ec2 create-route-table --vpc-id $VPCID | grep RouteTableId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')

RT_PRIVATE_SUB2=$(aws ec2 create-route-table --vpc-id $VPCID | grep RouteTableId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')

echo "aws ec2 create-nat-gateway --subnet-id $PRIVATE_SUBNET_1 --allocation-id $NAT_ALLOCATION1 |grep NatGatewayId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g'"

NAT_GATEWAY_1=$(aws ec2 create-nat-gateway --subnet-id $PRIVATE_SUBNET_1 --allocation-id $NAT_ALLOCATION1 |grep NatGatewayId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')

NAT_GATEWAY_2=$(aws ec2 create-nat-gateway --subnet-id $PRIVATE_SUBNET_2 --allocation-id $NAT_ALLOCATION2 |grep NatGatewayId|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')


echo "Waiting for Nat Gateway to become available..."

while [ "$NAT_STATE_1" != "available" ]
do
	echo "Still waiting.. for Nat1"
	sleep 10
	NAT_STATE_1=$(aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GATEWAY_1|grep State|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')
done


while [ "$NAT_STATE_2" != "available" ]
do
	echo "Still waiting.. for Nat2"
	sleep 10
	NAT_STATE_2=$(aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GATEWAY_2|grep State|awk '{print $2}'|sed 's/\"//g'|sed 's/,//g')
done

echo "Creating nat1 route for private subnet 1"
aws ec2 create-route --route-table-id $RT_PRIVATE_SUB1 --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GATEWAY_1


echo "Creating nat2 route for private subnet 2"
aws ec2 create-route --route-table-id $RT_PRIVATE_SUB2 --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GATEWAY_2

echo "Associate private net route table to private subnet1"
aws ec2 associate-route-table --route-table-id $RT_PRIVATE_SUB1 --subnet-id $PRIVATE_SUBNET_1


echo "Associate private net route table to private subnet2"
aws ec2 associate-route-table --route-table-id $RT_PRIVATE_SUB2 --subnet-id $PRIVATE_SUBNET_2

#aws ec2 create-tags --resources $NAT_GATEWAY_1  --tags Key=Name,Value="$VPCNAME"_NAT_GATEWAY_1
                   


#Associate all subnets into the main routing table.. so that they can talk to each other.

MAIN_ROUTE_TABLE=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPCID Name=association.main,Values=true|jq --raw-output .RouteTables[0].RouteTableId)
echo  "main Routing table $MAIN_ROUTE_TABLE" 
# echo "aws ec2 associate-route-table --route-table-id $MAIN_ROUTE_TABLE --subnet-id $PRIVATE_SUBNET_1"

# aws ec2 associate-route-table --route-table-id $MAIN_ROUTE_TABLE --subnet-id $PRIVATE_SUBNET_1
# aws ec2 associate-route-table --route-table-id $MAIN_ROUTE_TABLE --subnet-id $PRIVATE_SUBNET_2
# aws ec2 associate-route-table --route-table-id $MAIN_ROUTE_TABLE --subnet-id $PUBLIC_SUBNET_1
# aws ec2 associate-route-table --route-table-id $MAIN_ROUTE_TABLE --subnet-id $PUBLIC_SUBNET_2



echo "public subnet 1: $PUBLIC_SUBNET_1" 
echo "private subnet 1: $PRIVATE_SUBNET_1"

echo "public subnet 2: $PUBLIC_SUBNET_2"
echo "private subnet 2: $PRIVATE_SUBNET_2"

echo "Internet GateWay: $INTERNET_GATEWAY" 

export $VPCID $VPCNAME $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2
#chmod +x ./addConsulCluster.sh
./addConsulCluster.sh

#chmod +x ./addSwarmCluster.sh