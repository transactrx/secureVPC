 #!/bin/sh

set -e


SUBNET1=$PRIVATE_SUBNET_1
SUBNET2=$PRIVATE_SUBNET_2


SWARM_SG=$(aws ec2 create-security-group --vpc-id $VPCID --group-name $VPCNAME"-swarm" --description  "$VPCNAME swarm service SG"|jq -r .GroupId)
aws ec2 authorize-security-group-ingress --group-id $SWARM_SG --source-group $SWARM_SG --protocol tcp --port 0-65535 
aws ec2 authorize-security-group-ingress --group-id $SWARM_SG --source-group $SWARM_SG --protocol udp --port 0-65535 
aws ec2 authorize-security-group-ingress --group-id $SWARM_SG --source-group $SWARM_SG --protocol icmp --port -1

SWARM1_USER_DATA=$(cat $DIR/swarm/swarm1_userdata.sh|sed s/CONSUL_DNS_NAME/$CONSUL_DNS_NAME/g|base64)
SWARM2_USER_DATA=$(cat $DIR/swarm/swarm2_userdata.sh|sed s/CONSUL_DNS_NAME/$CONSUL_DNS_NAME/g|base64)
SWARM3_USER_DATA=$(cat $DIR/swarm/swarm3_userdata.sh|sed s/CONSUL_DNS_NAME/$CONSUL_DNS_NAME/g|base64)
SWARM_INSTANCE_TYPE=t2.nano 

SWARM1=$(aws ec2 run-instances --security-group-ids $SWARM_SG --instance-type $SWARM_INSTANCE_TYPE --subnet-id $SUBNET2 --private-ip-address 10.1.102.199 --image-id ami-10ae537d --user-data "$SWARM1_USER_DATA"|jq -r .Instances[0].InstanceId)
aws ec2 create-tags --resources $SWARM1  --tags Key=Name,Value="$VPCNAME"_SWARM1
SWARM2=$(aws ec2 run-instances --security-group-ids $SWARM_SG --instance-type $SWARM_INSTANCE_TYPE --user-data "$SWARM2_USER_DATA" --private-ip-address 10.1.101.199  --subnet-id $SUBNET1 --image-id ami-10ae537d|jq -r .Instances[0].InstanceId)
aws ec2 create-tags --resources $SWARM2  --tags Key=Name,Value="$VPCNAME"_SWARM2
SWARM3=$(aws ec2 run-instances --security-group-ids $SWARM_SG --instance-type $SWARM_INSTANCE_TYPE --user-data "$SWARM3_USER_DATA" --private-ip-address 10.1.101.200  --subnet-id $SUBNET1 --image-id ami-10ae537d|jq -r .Instances[0].InstanceId)
aws ec2 create-tags --resources $SWARM3  --tags Key=Name,Value="$VPCNAME"_SWARM3

#load balance the cluster

SWARM_ELB_SG=$(aws ec2 create-security-group --vpc-id $VPCID --group-name $VPCNAME"-swarm-elb" --description  "$VPCNAME swarm service ELB SG"|jq -r .GroupId)
aws ec2 authorize-security-group-ingress --group-id $SWARM_ELB_SG --cidr 0.0.0.0/0 --protocol tcp --port 4000
#Give access to the ELB to the swarm security group
aws ec2 authorize-security-group-ingress --group-id $SWARM_SG --source-group $SWARM_ELB_SG --protocol tcp --port 4000
echo "aws elb create-load-balancer --load-balancer-name $VPCNAME-SWARM-ELB --subnets $SUBNET1 $SUBNET2 --security-groups $SWARM_ELB_SG --listeners Protocol=tcp,LoadBalancerPort=4000,InstanceProtocol=tcp,InstancePort=4000 --scheme Internal"
SWARMELB=$(aws elb create-load-balancer --load-balancer-name "$VPCNAME"-SWARM-ELB --subnets $SUBNET1 $SUBNET2 --security-groups $SWARM_ELB_SG --listeners Protocol=tcp,LoadBalancerPort=4000,InstanceProtocol=tcp,InstancePort=4000 --scheme Internal)
aws elb configure-health-check --load-balancer-name "$VPCNAME"-SWARM-ELB --health-check Target=TCP:4000,Interval=30,UnhealthyThreshold=2,HealthyThreshold=4,Timeout=3
aws elb register-instances-with-load-balancer --load-balancer-name "$VPCNAME"-SWARM-ELB --instances $SWARM1 $SWARM2 $SWARM3
