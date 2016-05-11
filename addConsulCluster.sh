 #!/bin/sh

set -e

echo "Creating consul cluster for VPC =$VPCNAME" 

SUBNET1=$PUBLIC_SUBNET_1 
SUBNET2=$PUBLIC_SUBNET_2


CONSUL_SG=$(aws ec2 create-security-group --vpc-id $VPCID --group-name $VPCNAME"-consul" --description  "$VPCNAME consul service SG"|jq -r .GroupId)
aws ec2 authorize-security-group-ingress --group-id $CONSUL_SG --source-group $CONSUL_SG --protocol tcp --port 0-65535 
aws ec2 authorize-security-group-ingress --group-id $CONSUL_SG --source-group $CONSUL_SG --protocol udp --port 0-65535 
aws ec2 authorize-security-group-ingress --group-id $CONSUL_SG --source-group $CONSUL_SG --protocol icmp --port -1

CONSUL1_USER_DATA=$(cat consul1_userdata.sh|base64)
CONSUL2_USER_DATA=$(cat consul2_userdata.sh|base64)
CONSUL3_USER_DATA=$(cat consul3_userdata.sh|base64)
CONSUL_INSTANCE_TYPE=t2.nano 

CONSUL1=$(aws ec2 run-instances --security-group-ids $CONSUL_SG --instance-type $CONSUL_INSTANCE_TYPE --subnet-id $SUBNET1 --private-ip-address 10.1.1.99 --associate-public-ip-address --image-id ami-93e905fe --user-data "$CONSUL1_USER_DATA"|jq -r .Instances[0].InstanceId)
aws ec2 create-tags --resources $CONSUL1  --tags Key=Name,Value="$VPCNAME"_CONSUL1
CONSUL2=$(aws ec2 run-instances --security-group-ids $CONSUL_SG --instance-type $CONSUL_INSTANCE_TYPE --user-data "$CONSUL2_USER_DATA" --private-ip-address 10.1.2.99  --subnet-id $SUBNET2 --associate-public-ip-address --image-id ami-93e905fe|jq -r .Instances[0].InstanceId)
aws ec2 create-tags --resources $CONSUL2  --tags Key=Name,Value="$VPCNAME"_CONSUL2
CONSUL3=$(aws ec2 run-instances --security-group-ids $CONSUL_SG --instance-type $CONSUL_INSTANCE_TYPE --user-data "$CONSUL3_USER_DATA" --private-ip-address 10.1.2.100  --subnet-id $SUBNET2 --associate-public-ip-address --image-id ami-93e905fe|jq -r .Instances[0].InstanceId)
aws ec2 create-tags --resources $CONSUL3  --tags Key=Name,Value="$VPCNAME"_CONSUL3

#load balance the cluster

CONSUL_ELB_SG=$(aws ec2 create-security-group --vpc-id $VPCID --group-name $VPCNAME"-consul-elb" --description  "$VPCNAME consul service ELB SG"|jq -r .GroupId)
aws ec2 authorize-security-group-ingress --group-id $CONSUL_ELB_SG --cidr 0.0.0.0/0 --protocol tcp --port 8500
#Give access to the ELB to the consul security group
aws ec2 authorize-security-group-ingress --group-id $CONSUL_SG --source-group $CONSUL_ELB_SG --protocol tcp --port 8500
echo "aws elb create-load-balancer --load-balancer-name $VPCNAME-CONSUL-ELB --subnets $SUBNET1 $SUBNET2 --security-groups $CONSUL_ELB_SG --listeners Protocol=tcp,LoadBalancerPort=8500,InstanceProtocol=tcp,InstancePort=8500 --scheme Internal"
CONSULELB=$(aws elb create-load-balancer --load-balancer-name "$VPCNAME"-CONSUL-ELB --subnets $SUBNET1 $SUBNET2 --security-groups $CONSUL_ELB_SG --listeners Protocol=tcp,LoadBalancerPort=8500,InstanceProtocol=tcp,InstancePort=8500 --scheme Internal)
aws elb configure-health-check --load-balancer-name "$VPCNAME"-CONSUL-ELB --health-check Target=HTTP:8500/v1/catalog/nodes,Interval=30,UnhealthyThreshold=2,HealthyThreshold=4,Timeout=3
aws elb register-instances-with-load-balancer --load-balancer-name "$VPCNAME"-CONSUL-ELB --instances $CONSUL1 $CONSUL2 $CONSUL3
