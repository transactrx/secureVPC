 #!/bin/bash

echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCd6z5m1NOdHhjdXT4ltZuNdJN7doKOBiRBX00Qqch9BKGvsoUUvQQQw88DkBiq4vrCsSjX3PsPCLJ+ADTAnhPjzk7sdAYISfU2RSgYGmfArP2txJMqK0nbdI1HVXagFOGX2AYDPs7J9IJnyaOGO2ZFHfy7gF89PTy3B2FThBlYxzJSTHfdwdyP4bjghe03F3TaoAzOOvlDgoPz7Gn9IOngDIuaMpESljJEPRyRjD2LS0IuHoExz/fTZ2/Zz41dXhWzXZnRtSHOWFJKEeuHerv1YzLjhCbbm7+4VTgE5NNULfqw9uL9dxo+IcLmEzDo9eRjA7vKInBJrxQefTqgUNkz melaraj@Manuels-MacBook-Pro.local" >> /home/ec2-user/.ssh/authorized_keys

echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZlrf0UCfHlQm184M4g/7+RSSqUmDbmrtQw4qCLHZ8ZNH/K0Zl8bqf+o4Y/l+VDSaclLc4gtoV95IezgMP94rlee+eFNAGAdtxhPUJPSvHgzY4TvSK2x4NSeTEDfsP+nxMNeZ4UPfVw1GZqmy8Z48mD6nbm2v0Oyt90PfpkyoNfqfIICmBQpTEZ6agw2iWoYVbqUSjC/V5RuKVkZK8QQNAjfXjaw9AIMPzLlkpAq4TGPK3jdHElgZTEZSWYXxDi7fB8sABvgMP0mE3LhpQfCZgcLwESAA6Ypth0mjm0eIjRUdN1xTficWoVT5EI1WUMI2y2GPQzdeTzCPzgJzK373J oresteslorda@Orestess-MBP" >> /home/ec2-user/.ssh/authorized_keys

yum update -y
yum install docker -y
service docker start
mkdir -p /opt/consuldata
ipaddr=$(ifconfig | awk '/inet addr/{print substr($2,6)}'|grep 10.)
docker run -d -p 4000:4000 swarm manage -H :4000 --replication --advertise $ipaddr:4000 consul://CONSUL_DNS_NAME:8500

echo "service docker start" >> /etc/rc.local
reboot
