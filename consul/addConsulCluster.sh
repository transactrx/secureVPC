 #!/bin/sh

set -e

#echo "Creating consul cluster for VPC =$VPCNAME" 

SUBNET1=$PRIVATE_SUBNET_1 
SUBNET2=$PRIVATE_SUBNET_2


export CONSUL_SG=$(aws ec2 create-security-group --vpc-id $VPCID --group-name $VPCNAME"-consul" --description  "$VPCNAME consul service SG"|jq -r .GroupId)
aws ec2 authorize-security-group-ingress --group-id $CONSUL_SG --source-group $CONSUL_SG --protocol tcp --port 0-65535 
aws ec2 authorize-security-group-ingress --group-id $CONSUL_SG --source-group $CONSUL_SG --protocol udp --port 0-65535 
aws ec2 authorize-security-group-ingress --group-id $CONSUL_SG --source-group $CONSUL_SG --protocol icmp --port -1

CONSUL1_USER_DATA=$(cat $DIR/consul/consul1_userdata.sh|base64)
CONSUL2_USER_DATA=$(cat $DIR/consul/consul2_userdata.sh|base64)
CONSUL3_USER_DATA=$(cat $DIR/consul/consul3_userdata.sh|base64)
CONSUL_INSTANCE_TYPE=t2.nano 

export CONSUL1=$(aws ec2 run-instances --security-group-ids $CONSUL_SG --instance-type $CONSUL_INSTANCE_TYPE --subnet-id $SUBNET1 --private-ip-address 10.1.101.99 --image-id ami-10ae537d --user-data "$CONSUL1_USER_DATA"|jq -r .Instances[0].InstanceId)
export CONSUL2=$(aws ec2 run-instances --security-group-ids $CONSUL_SG --instance-type $CONSUL_INSTANCE_TYPE --user-data "$CONSUL2_USER_DATA" --private-ip-address 10.1.102.99  --subnet-id $SUBNET2 --image-id ami-10ae537d|jq -r .Instances[0].InstanceId)
export CONSUL3=$(aws ec2 run-instances --security-group-ids $CONSUL_SG --instance-type $CONSUL_INSTANCE_TYPE --user-data "$CONSUL3_USER_DATA" --private-ip-address 10.1.102.100  --subnet-id $SUBNET2 --image-id ami-10ae537d|jq -r .Instances[0].InstanceId)

#give instances time to get going
sleep 20
aws ec2 create-tags --resources $CONSUL1  --tags Key=Name,Value="$VPCNAME"_CONSUL1
aws ec2 create-tags --resources $CONSUL2  --tags Key=Name,Value="$VPCNAME"_CONSUL2
aws ec2 create-tags --resources $CONSUL3  --tags Key=Name,Value="$VPCNAME"_CONSUL3

#load balance the cluster

export CONSUL_ELB_SG=$(aws ec2 create-security-group --vpc-id $VPCID --group-name $VPCNAME"-consul-elb" --description  "$VPCNAME consul service ELB SG"|jq -r .GroupId)
aws ec2 authorize-security-group-ingress --group-id $CONSUL_ELB_SG --cidr 0.0.0.0/0 --protocol tcp --port 8500
#Give access to the ELB to the consul security group

aws ec2 authorize-security-group-ingress --group-id $CONSUL_SG --source-group $CONSUL_ELB_SG --protocol tcp --port 8500
#echo "aws elb create-load-balancer --load-balancer-name $CONSUL_ELB_NAME --subnets $SUBNET1 $SUBNET2 --security-groups $CONSUL_ELB_SG --listeners Protocol=tcp,LoadBalancerPort=8500,InstanceProtocol=tcp,InstancePort=8500 --scheme Internal"
CONSULELB=$(aws elb create-load-balancer --load-balancer-name $CONSUL_ELB_NAME --subnets $SUBNET1 $SUBNET2 --security-groups $CONSUL_ELB_SG --listeners Protocol=tcp,LoadBalancerPort=8500,InstanceProtocol=tcp,InstancePort=8500 --scheme Internal)
aws elb configure-health-check --load-balancer-name $CONSUL_ELB_NAME --health-check Target=HTTP:8500/v1/catalog/nodes,Interval=30,UnhealthyThreshold=2,HealthyThreshold=4,Timeout=3
aws elb register-instances-with-load-balancer --load-balancer-name $CONSUL_ELB_NAME --instances $CONSUL1 $CONSUL2 $CONSUL3
export CONSUL_DNS_NAME=$(aws elb describe-load-balancers --load-balancer-names $CONSUL_ELB_NAME |jq -r .LoadBalancerDescriptions[0].DNSName)

echo "  var x={};\
		x.CONSUL_SG=process.env.CONSUL_SG;\
		x.CONSUL_INSTANCE_ID1=process.env.CONSUL1;\
		x.CONSUL_INSTANCE_ID2=process.env.CONSUL2;\
		x.CONSUL_INSTANCE_ID3=process.env.CONSUL3;\
		x.CONSUL_ELB_SG=process.env.CONSUL_ELB_SG;\
		x.CONSUL_DNS_NAME=process.env.CONSUL_DNS_NAME;\
		x.CONSUL_PORT='8500';\
	    console.log(JSON.stringify(x))"|node > $DIR/consulclusterresult.json


