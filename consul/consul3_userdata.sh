 #!/bin/bash

echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCd6z5m1NOdHhjdXT4ltZuNdJN7doKOBiRBX00Qqch9BKGvsoUUvQQQw88DkBiq4vrCsSjX3PsPCLJ+ADTAnhPjzk7sdAYISfU2RSgYGmfArP2txJMqK0nbdI1HVXagFOGX2AYDPs7J9IJnyaOGO2ZFHfy7gF89PTy3B2FThBlYxzJSTHfdwdyP4bjghe03F3TaoAzOOvlDgoPz7Gn9IOngDIuaMpESljJEPRyRjD2LS0IuHoExz/fTZ2/Zz41dXhWzXZnRtSHOWFJKEeuHerv1YzLjhCbbm7+4VTgE5NNULfqw9uL9dxo+IcLmEzDo9eRjA7vKInBJrxQefTqgUNkz melaraj@Manuels-MacBook-Pro.local" >> /home/ec2-user/.ssh/authorized_keys

echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZlrf0UCfHlQm184M4g/7+RSSqUmDbmrtQw4qCLHZ8ZNH/K0Zl8bqf+o4Y/l+VDSaclLc4gtoV95IezgMP94rlee+eFNAGAdtxhPUJPSvHgzY4TvSK2x4NSeTEDfsP+nxMNeZ4UPfVw1GZqmy8Z48mD6nbm2v0Oyt90PfpkyoNfqfIICmBQpTEZ6agw2iWoYVbqUSjC/V5RuKVkZK8QQNAjfXjaw9AIMPzLlkpAq4TGPK3jdHElgZTEZSWYXxDi7fB8sABvgMP0mE3LhpQfCZgcLwESAA6Ypth0mjm0eIjRUdN1xTficWoVT5EI1WUMI2y2GPQzdeTzCPzgJzK373J oresteslorda@Orestess-MBP" >> /home/ec2-user/.ssh/authorized_keys


function installDocker {
	set +e
	echo "updating yum"
	yum update -y
	if [ $? -eq 0 ]; then
		YUM_UPDATED='yes'
	else
		YUM_UPDATED='no'
	fi
	yum install docker -y	
	if [ $? -eq 0 ]; then
		DOCKER_UPDATED='yes'
	else
		DOCKER_UPDATED='no'
	fi
	set -e
}

installDocker
attempt=1
#we will try for 10 minutes;
while [$DOCKER_UPDATED != 'yes']||[$YUM_UPDATED != 'yes'] && [$attempt<6] 
do
	wait 120
	echo "Attempt to install docker again " +$attempt
	attempt=`expr $attempt + 1`
	installDocker
done
##finished installing docker

service docker start
mkdir -p /opt/consuldata

docker run --name consul3 --restart=always -h consul3 \
	-v /opt/consuldata:/data -p 8300:8300 \
	-p 8301:8301 \
	-p 8301:8301/udp \
	-p 8302:8302 \
	-p 8302:8302/udp \
	-p 8400:8400 \
	-p 8500:8500 \
	-p 172.17.0.1:53:53 \
	-p 172.17.0.1:53:53/udp -d \
	progrium/consul -server  -join 10.1.101.99 -advertise 10.1.102.100 \
	 -ui-dir /ui

echo "service docker start" >> /etc/rc.local
reboot