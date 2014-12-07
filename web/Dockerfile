# Apache2 On Ubuntu:14.04 (Ubuntu_Trusty)
#
# VERSION 1.0

# use Ubunty Trusty as base image
FROM ubuntu:14.04

# specify the maintainer
MAINTAINER Arijit Sarcar, sarcar_a@yahoo.com

# install apache2
RUN apt-get update && apt-get install -y apache2

# expose http port
# EXPOSE 80

ENV SERVERNAME "docker-ubuntu-www"

COPY index.html /var/www/html/

# the command to run
CMD ["/usr/sbin/apachectl", "-D", "FOREGROUND"]
