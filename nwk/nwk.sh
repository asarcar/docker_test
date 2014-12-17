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
# --detach: 
#              detached mode: Run container in the background, print new container id
# --dns        x.y.z.w 
# --dns-search abc.def
# --rm:        automatically remove container when it exits
# --hostname:  populates /etc/hostname and uses it to reference from other containers
# --expose:    expose a port or a range of ports from the container
# --publish:   set up NAT rules so that entities outside the docker0 bridge may connect
docker run --detach=true --name=u1 --hostname=d1 --expose=2222 --publish=3333:2222 ubuntu nc -l -p 2222
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
# Run name: u, image: ubuntu:latest, hostname d
docker run --detach=true --name=u --hostname=d --expose=2222 --publish=3333:2222 ubuntu nc -l -p 2222
# Get the IP Address of the container and port number
CIP1=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' u)
nc -v -z localhost 3333
echo "Tested connection between base system to docker container $CIP1"
docker stop u > /dev/null
docker rm u > /dev/null

echo "Testing connectivity between isolated container and base system connected by a wire"
# Run: u1
# --interactive=false:  
#              keep stdin open even if not attached
# --tty=false: allocate a pseudo-tty
docker run --interactive=true --tty=true --detach=true --net=none --name=u ubuntu /bin/bash
PID=$(sudo docker inspect --format='{{.State.Pid}}' u)
# create the wire
ip link add ethu type veth peer name ethb
ip link set ethu netns $PID
# Create a linked file entry for net NS e.g. we can execute ip netns exec $PID cmd
ln -s /proc/$PID/ns/net /var/run/netns/$PID
ip netns exec $PID ip link set ethu name eth0
# bring up the links on both ends
ip link set ethb up
ip netns exec $PID ip link set eth0 up
ip addr add 10.1.1.2/32 dev ethb
ip route add 10.1.1.1/32 dev ethb
ip netns exec $PID ip addr add 10.1.1.1/32 dev eth0
ip netns exec $PID ip route add 10.1.1.2/32 dev eth0
if /bin/ping -c1 -W1 10.1.1.1 > /dev/null 2>&1; then
  echo "SUCCESS: Tested connection between base (10.1.1.2) to docker (10.1.1.1)"
else
  echo "FAILED: Test connection between base (10.1.1.2) to docker (10.1.1.1)"
fi
# Clean up all state created: docker containers and symbolic links
docker stop u > /dev/null
docker rm u > /dev/null
find -L /var/run/netns -type l -delete
