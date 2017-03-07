FROM 529621320452.dkr.ecr.us-east-1.amazonaws.com/debezium-kafka

MAINTAINER Josh

EXPOSE 8081

COPY schema-registry-docker.sh /
COPY schema-registry.properties $KAFKA_HOME/config/schema-registry.properties
RUN curl -fSL -o /tmp/confluent-package.tar.gz \
 http://packages.confluent.io/archive/3.1/confluent-oss-3.1.2-2.11.tar.gz

RUN mkdir -p /tmp/confluent-package/
RUN tar -xvf /tmp/confluent-package.tar.gz -C /tmp/confluent-package/
RUN mkdir -p /kafka/share/java/
RUN ls -l /tmp/confluent-package/
RUN cp -r /tmp/confluent-package/confluent-3.1.2/share/java/confluent-common /kafka/share/java/
RUN cp -r /tmp/confluent-package/confluent-3.1.2/share/java/schema-registry /kafka/share/java/
RUN cp -r /tmp/confluent-package/confluent-3.1.2/share/java/rest-utils /kafka/share/java/
RUN cp -r /tmp/confluent-package/confluent-3.1.2/share/java/kafka-serde-tools /kafka/share/java/
RUN cp /tmp/confluent-package/confluent-3.1.2/bin/*schema* /kafka/bin/

RUN rm -rf /tmp/confluent-package/

#
# The `docker-entrypoint.sh` script will automatically discover the child directories
# within the $KAFKA_CONNECT_PLUGINS_DIR directory (e.g., `/kafka/connect`), and place
# all of the files in those child directories onto the Java classpath.
#
# The general recommendation is to create a separate child directory for each connector
# (e.g., "debezium-connector-mysql"), and to place that connector's JAR files 
# and other resource files in that child directory.
#
# However, use a single directory for connectors when those connectors share dependencies.
# This will prevent the classes in the shared dependencies from appearing in multiple JARs
# on the classpath, which results in arcane NoSuchMethodError exceptions.
#
USER root
RUN rm $KAFKA_HOME/config/schema-registry.properties
COPY schema-registry.properties /tmp/schema-registry.properties
RUN chown kafka:kafka /tmp/schema-registry.properties
RUN mv /tmp/schema-registry.properties $KAFKA_HOME/config/schema-registry.properties

ENV GOSU_VERSION 1.10
RUN set -x \
    && apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
    && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && apt-get purge -y --auto-remove ca-certificates wget
ENTRYPOINT ["/schema-registry-docker.sh"]
CMD ["/bin/chown -R kafka:kafka /kafka/ && gosu kafka /schema-registry-docker.sh","'start'"]
