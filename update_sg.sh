#!/bin/bash

# A script to update my AWS security when my ADSL IP address changes
#
# 26-AUG-2016 Gaius Initial version

# get whatever is the most recent Amazon Linux AMI
AMI=$(aws ec2 describe-images --owners amazon \
	  --filter Name=description,Values="*Amazon Linux*" \
	  --query "Images[*].[ImageId, CreationDate, Description]" \
	  --output text \
	     |sort -r -k 2|head -1|awk '{print $1}')

# get the default security group for my VPC
SG=$(aws ec2 describe-security-groups --query "SecurityGroups[*].[GroupId, VpcId]" \
	 --output text \
	    |awk '/vpc/ {print $1}')

# get my default subnet
SUBNET=$(aws ec2 describe-subnets --query "Subnets[*].SubnetId" \
	     --output text)

# spin up an instance with these values
INST_ID=$(aws ec2 run-instances --image-id $AMI \
	      --security-group-ids $SG \
	      --count 1 \
	      --instance-type t2.micro \
	      --subnet-id $SUBNET \
	      --associate-public-ip-address \
	      --user-data file://userdata.sh \
	      --query "Instances[0].InstanceId" \
	      --output text)

# find its IP address
IP_ADDRESS=$(aws ec2 describe-instances --instance-id $INST_ID \
		 --query "Reservations[0].Instances[0].PublicIpAddress" \
		 --output text)

# allow port 8080 inbound from anywhere - ignore if already exists
aws ec2 authorize-security-group-ingress \
    --group-id $SG \
    --protocol tcp \
    --port 8080 \
    --cidr 0.0.0.0/0  2>/dev/null

# wait for the instance to become available and get the output
URL="http://${IP_ADDRESS}:8080/whatsmyip"
echo -n Waiting for instance $INST_ID @ $IP_ADDRESS
while MY_IP=$(curl -s $URL); test $? -ne 0
do
    echo -n .
    sleep 10
done
echo OK

# remove the existing one
OLD_IP=$(aws ec2 describe-security-groups \
	     --group-ids $SG \
	     --query 'SecurityGroups[*].IpPermissions[*].[FromPort==`22`, IpRanges]' \
	     --output text \
		|grep -A 1 True|grep -v True)
if [ ! -z "$OLD_IP" ]; then
    aws ec2 revoke-security-group-ingress --group-id $SG --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "'${OLD_IP}'"}]}]'
    echo '>>>' Removed $OLD_IP from $SG
fi

aws ec2 authorize-security-group-ingress \
    --group-id $SG \
    --protocol tcp \
    --port 22 \
    --cidr ${MY_IP}/32

echo '>>>' Security group $SG is now configured as:
aws ec2 describe-security-groups \
    --query 'SecurityGroups[?GroupId==`'${SG}'`].IpPermissions[*].[ToPort, IpRanges]' \
    --output text \
    |awk 'ORS=NR%2?FS:RS' \
    |awk '{print $2 " --> " $1}'

# now destroy it
aws ec2 terminate-instances --instance-id $INST_ID >/dev/null

# EOF
