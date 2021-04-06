#!/bin/bash
#
#
# A simple script to automate the initial enumeration process

echo "Attempting scan on $1"
echo "Checking connectivity..."

mkdir $1

# Use ping to check  if host is reachable
ping -c 4 $1 > $1/$1-ping.log

ANS=`grep -i "transmitted" $1/$1-ping.log | awk '{if ($4>0) print "true"; else print "false"}'`

if [ $ANS == 'true' ]
then
	echo "Connection successful!"
else
	echo "Host is either unreachable or blocking ICMP requests :("
	exit 0
fi

echo "Beginning nmap to discover open ports..."

ports=$(nmap -Pn -p- --min-rate=1000  -T5 $1 | grep ^[0-9] | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)

echo "Ports discovered: $ports"
echo "..."
echo "Performing detailed scan of open ports..."

nmap -Pn -oA "$1//$1" -sC -sV -p$ports $1

https=$(cat $1/$1.nmap | grep http | grep tcp | awk '{print $1}' | sed 's/\/tcp$//' | tr '\n' ',' | sed s/,$//)

echo "..."
echo "Ports running http(s): $https"
echo "Beginning dirbuster scans..."

IFS=',' read -r -a weblist <<< "$https"


for FOO in "${weblist[@]}"
do
	echo "Conducting directory sweep of http://$1:$FOO"
	mkdir $1/$FOO
	gobuster dir -w /usr/share/wordlists/dirb/big.txt -u http://$1:$FOO/ -k -q -o $1/$FOO/gobuster_results > /dev/null	
	paths=$(grep -v "403" $1/$FOO/gobuster_results | awk '{print $1}' | tr '\n' ', ' | sed 's/,$/\n/')
	echo "URL paths found: $paths"
done

# check for bad ssh keys
if [[ $ports == *"22"* ]]
then
	echo "Checking for bad ssh keys..."
	ssh-keyscan $1
fi
