FROM mysql:5.7

MAINTAINER Debezium Community

COPY mysql.cnf /etc/mysql/conf.d/
COPY inventory.sql /docker-entrypoint-initdb.d/

RUN yum -y install wget curl dig
