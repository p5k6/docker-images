#!/bin/bash
set -x 
set -e

SR_CFG_FILE="$KAFKA_HOME/config/schema-registry.properties"

# Download the config file, if given a URL
if [ ! -z "$SR_CFG_URL" ]; then
  echo "[SR] Downloading SR config file from ${SR_CFG_URL}"
  curl --location --silent --insecure --output ${SR_CFG_FILE} ${SR_CFG_URL}
  if [ $? -ne 0 ]; then
    echo "[SR] Failed to download ${SR_CFG_URL} exiting."
    exit 1
  fi
fi

# Exit immediately if a *pipeline* returns a non-zero status. (Add -x for command tracing)
set -e
set -x

if [[ -z "$KAFKASTORE_CONNECTION_URL" ]]; then
    # Look for any environment variables set by Docker container linking. For example, if the container
    # running Kafka were aliased to 'kafka' in this container, then Docker should have created several envs,
    # such as 'KAFKA_PORT_9092_TCP'. If so, then use that to automatically set the 'bootstrap.servers' property.
    KAFKASTORE_CONNECTION_URL=$(env | grep .*PORT_9092_TCP= | sed -e 's|.*tcp://||' | uniq | paste -sd ,)
fi
# really the IP of the docker instance, in our env class B private (172.16-31.x.x)
if [[ -z "$HOST_NAME" ]]; then
    HOST_NAME=$(ip addr | grep 'BROADCAST' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')
fi

if [[ -z "$PORT" ]]; then
  PORT=8081
fi

if [[ -z "$DEBUG" ]]; then
  DEBUG=false
fi

HOST_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
ZOOKEEPER1_IP=$(getent hosts zookeeper-1.ecs.internal | awk '{print $1}')
ZOOKEEPER2_IP=$(getent hosts zookeeper-2.ecs.internal | awk '{print $1}')
ZOOKEEPER3_IP=$(getent hosts zookeeper-3.ecs.internal | awk '{print $1}')
TOPIC=_schemas

case $HOST_IP in 
  $ZOOKEEPER1_IP)
    BROKER_ID="1"
    export ZOOKEEPER_HOST_NAME=zookeeper-1.ecs.internal
    ;;
  $ZOOKEEPER2_IP)
    BROKER_ID="2"
    export ZOOKEEPER_HOST_NAME=zookeeper-2.ecs.internal
    ;;
  $ZOOKEEPER3_IP)
    BROKER_ID="3"
    export ZOOKEEPER_HOST_NAME=zookeeper-3.ecs.internal
    ;;
esac

: ${ADVERTISED_HOST_NAME:=$ZOOKEEPER_HOST_NAME}
: ${KAFKASTORE_CONNECTION_URL:=$KAFKASTORE_CONNECTION_URL}
export SR_PORT=$PORT
export SR_KAFKASTORE_CONNECTION_URL=$KAFKASTORE_CONNECTION_URL
export SR_HOST_NAME=$ADVERTISED_HOST_NAME
export SR_DEBUG=$DEBUG
export SR_TOPIC=$TOPIC
unset HOST_NAME
unset ADVERTISED_HOST_NAME
unset ZOOKEEPER_HOST_NAME
unset KAFKASTORE_CONNECTION_URL
unset TOPIC
unset DEBUG

#
# Set up the JMX options
#
#: ${JMXAUTH:="false"}
#: ${JMXSSL:="false"}
#if [[ -n "$JMXPORT" && -n "$JMXHOST" ]]; then
#    echo "Enabling JMX on ${JMXHOST}:${JMXPORT}"
#    export KAFKA_JMX_OPTS="-Djava.rmi.server.hostname=${JMXHOST} -Dcom.sun.management.jmxremote.rmi.port=${JMXPORT} -Dcom.sun.management.jmxremote.port=${JMXPORT} -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=${JMXAUTH} -Dcom.sun.management.jmxremote.ssl=${JMXSSL} "
#fi

#
# Make sure the directory for logs exists ...
#
# Process the argument to this container ...
case $1 in
    start)
        if [[ "x$SR_KAFKASTORE_CONNECTION_URL" = "x" ]]; then
            echo "The KAFKASTORE_CONNECTION_URL variable must be set, or the container must be linked to one that runs Kafka."
            exit 1
        fi

        echo "Using the following environment variables:"
        echo "      KAFKASTORE_CONNECTION_URL=$SR_KAFKASTORE_CONNECTION_URL"
        echo "      HOST_NAME=$SR_HOST_NAME"
        echo "      PORT=$SR_PORT"
        echo "      DEBUG=$SR_DEBUG"
        echo "      TOPIC=$SR_TOPIC"

        #
        # Configure the log files ...
        #
        if [[ -z "$LOG_LEVEL" ]]; then
            LOG_LEVEL="INFO"
        fi
        sed -i -r -e "s|=INFO, stdout|=$LOG_LEVEL, stdout|g" $KAFKA_HOME/config/log4j.properties
        sed -i -r -e "s|^(log4j.appender.stdout.threshold)=.*|\1=${LOG_LEVEL}|g" $KAFKA_HOME/config/log4j.properties
        export KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:$KAFKA_HOME/config/log4j.properties"
        
        #
        # Process all environment variables that start with 'SR_' 
        #
        for VAR in `env`
        do
          env_var=`echo "$VAR" | sed -r "s/(.*)=.*/\1/g"`
          if [[ $env_var =~ ^SR ]]; then
            prop_name=`echo "$VAR" | sed -r "s/^SR_(.*)=.*/\1/g" | tr '[:upper:]' '[:lower:]' | tr _ .`
            if egrep -q "(^|^#)$prop_name=" $KAFKA_HOME/config/schema-registry.properties; then
                #note that no config names or values may contain an '@' char
                sed -r -i "s@(^|^#)($prop_name)=(.*)@\2=${!env_var}@g" $KAFKA_HOME/config/schema-registry.properties
            else
                #echo "Adding property $prop_name=${!env_var}"
                echo -e "\n$prop_name=${!env_var}\n" >> $KAFKA_HOME/config/schema-registry.properties
            fi
            echo "--- Setting property from $env_var: $prop_name=${!env_var}"
          fi
        done

        #
        # Execute the schema registry distributed service, replacing this shell process with the specified program ...
        #        
        exec /kafka/bin/schema-registry-start ${SR_CFG_FILE}

        ;;
esac

# Otherwise just run the specified command
exec "$@"
