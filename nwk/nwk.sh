#!/bin/sh

user=$(whoami)
if [ $user != "root" ]; then
  echo "$user != root. Usage: sudo sh nwk.sh";
  return;
fi

# Communication between containers to outside world is allowed when
# /proc/sys/net/ipv4/ip_forward has 1

echo "Testing connection between 2 docker containers on the same bridge"
# Run name: u1, image: ubuntu:latest, hostname d1
# --dns        x.y.z.w 
# --dns-search abc.def
# --rm:        automatically remove container when it exits
# --hostname:  populates /etc/hostname and uses it to reference from other containers
# --expose:    expose a port or a range of ports from the container
# --publish:   set up NAT rules so that entities outside the docker0 bridge may connect
docker run -d --name=u1 --hostname=d1 --expose=2222 --publish=3333:2222 ubuntu nc -l -p 2222
CIP1=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' u1)

# Run name: u2, image: ubuntu, hostname d2
# --link:      populates /etc/hosts and allows to connec to linked container at the exposed port
#              Note the port on the destination container must be exposed.
#              Allow u2 to refer to u1 by hostname d1: resolves to the 
#              valid IP of u1 even if the IP changes (managed by docker) 
docker run --name=u2 --hostname=d2 --link=u1:d1 --rm ubuntu nc -v -z $CIP1 2222
echo "Tested connection between docker container u2 to docker container $CIP1 (u1)"
docker stop u1 > /dev/null
docker rm u1 > /dev/null

echo "Testing connection between outside docker bridge to docker container"
# Run name: u1, image: ubuntu:latest, hostname d1
docker run -d --name=u1 --hostname=d1 --expose=2222 --publish=3333:2222 ubuntu nc -l -p 2222
# Get the IP Address of the container and port number
CIP1=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' u1)
nc -v -z localhost 3333
echo "Tested connection between outside docker bridge $MYIP to docker container $CIP1"
docker stop u1 > /dev/null
docker rm u1 > /dev/null
