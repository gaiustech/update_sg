#!/bin/bash

yum -y update
yum -y install docker
service docker start
usermod -a -G docker ec2-user
docker run -p 8080:8080 gaius/whatsmyip

# EOF
