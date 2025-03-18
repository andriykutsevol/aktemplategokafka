.SILENT: ;				 # no need for @
.ONESHELL: ;             # recipes execute in same shell
.NOTPARALLEL: ;          # wait for this target to finish
.EXPORT_ALL_VARIABLES: ; # send all vars to shell


SHELL          := $(shell which bash)
ROOT_DIR       := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
DEPLOYMENTS    := $(ROOT_DIR)/deployments


#	The --progress=plain is mandatory if you want to look at RUN ls /opt/app command
# 	You could also disable buildkit (not recommended)
#	export DOCKER_BUILDKIT=0
#   If you want to keep buildkit and make it print commands output, then:
BUILDKIT_PROGRESS=plain
#BUILDKIT_PROGRESS=auto	# (default): Allows BuildKit to choose the most suitable output format.
#BUILDKIT_PROGRESS=tty	# Uses a fancy progress display that groups and summarizes each stage of the build. 
#						This is the default when BuildKit is enabled and the terminal supports TTY.

export BUILDKIT_PROGRESS
#	or use --progress=plain with the "docker build" or "docker-compose ... build ..."


# By default, variables defined in a Makefile are only available inside Make itself. 
# They do not automatically become environment variables for subprocesses (like docker-compose).
# BUT:
# .env File Loading:
# docker-compose itself looks for an .env file in the same directory as the docker-compose.yml by default. 
# If it finds one, it loads the variables and makes them available
# for substitution in the docker-compose.yml file.

ENVFILE = .env_dev
include $(ENVFILE)





#-----------------------------------------------------------------------------
# Usecases:
# ----------------------
# 1) kafka_up
# 2) up_producer
# 3) bash_producer
# 4) up_consumer
# 5) bash_consumer
# ----------------------


#-----------------------------------------------------------------------------





.PHONY: create_network
create_network: 
	/bin/bash $(DEPLOYMENTS)/create_network.sh


.PHONY: rm_network
rm_network: 
	/bin/bash $(DEPLOYMENTS)/remove_network.sh

# $ docker exec -it zookeeper bash		# Name of a container, not service name
# $ docker exec -it kafka bash			# Name of a container, not service name
.PHONY: kafka_up
kafka_up: create_network
	docker-compose --project-name $(PROJECT_NAME) -f $(DEPLOYMENTS)/docker-compose.yml --profile kfk up -d


# $ docker exec -it kafka bash -c "cat /opt/bitnami/kafka/config/server.properties | grep num.partitions"
# num.partitions=2



# $ docker exec -it kafka bash -c "/opt/bitnami/kafka/bin/kafka-configs.sh --bootstrap-server localhost:9092 --describe --entity-type brokers --entity-name 0 --describe"
# Dynamic configs for broker 0 are:
# This hangs, why?

# This works
# $ docker exec -it kafka bash -c "/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic orders | grep PartitionCount | awk '{print $2}'"
# Topic: orders   TopicId: IhlmJBrSQI2_obYTEJ11KQ PartitionCount: 2       ReplicationFactor: 1    Configs: 

# $ docker exec -it kafka bash -c "/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic orders"
# Topic: orders   TopicId: IhlmJBrSQI2_obYTEJ11KQ PartitionCount: 2       ReplicationFactor: 1    Configs: 
#         Topic: orders   Partition: 0    Leader: 1001    Replicas: 1001  Isr: 1001       Elr: N/A        LastKnownElr: N/A
#         Topic: orders   Partition: 1    Leader: 1001    Replicas: 1001  Isr: 1001       Elr: N/A        LastKnownElr: N/A





# The broker variable should point to Kafka itself, not Zookeeper.
# In your case, since you're using Docker Compose, you should configure broker 
# to be the Kafka broker's advertised listener (e.g., kafka:9092 if using Docker networking).
# Zookeeper is only used by Kafka internally for managing metadata,
# but your producer and consumer interact directly with Kafka brokers.

# The docker exec command is used to run a new command in a running container.

# Example Topic Creation:
# $ docker exec -it kafka bash -c "/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --topic orders --partitions 2 --replication-factor 1"
# Created topic orders.

# Verification:
# docker exec -it kafka bash -c "/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list"

# Delete Topic:
# docker exec -it kafka bash -c "/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic orders"




#-----------------------------------------------------------------------------


# The export in the Makefile is mainly for passing variables to the shell environment, 
# but the variables defined in the .env file will be automatically picked up by docker-compose 
# without needing to be exported in the Makefile.

# PRODUCER_ONNETWORK=172.18.3.4 in the .env file will be used by docker-compose 
# to substitute ${PRODUCER_ONNETWORK} in the docker-compose.yml file.

# Since docker-compose loads the .env file by default, you do not need to use export in your Makefile 
# for the .env variables to be available to docker-compose. 
# You can directly reference the variables in your docker-compose.yml, 
# and docker-compose will automatically replace them with the values from the .env file.

# You only need to export the variables if you're passing them from the Makefile 
# to other commands outside of docker-compose.



.PHONY: build_producer
build_producer:
	export CONTEXT=$(ROOT_DIR)/producer
	export BROKER=$(KAFKA_IP_ONNETWORK):$(KAFKA_PORT_ONNETWORK)
	export COMMAND=/bin/bash
	docker-compose -f $(DEPLOYMENTS)/docker-compose.yml build producer_dev


.PHONY: up_producer
up_producer: build_producer
	export CONTEXT=$(ROOT_DIR)/producer
	export BROKER=$(KAFKA_IP_ONNETWORK):$(KAFKA_PORT_ONNETWORK)
	export COMMAND=/bin/bash
	docker-compose --project-name $(PROJECT_NAME) -f $(DEPLOYMENTS)/docker-compose.yml --profile producer up -d

.PHONY: bash_producer
bash_producer:
	docker-compose --project-name $(PROJECT_NAME) -f $(DEPLOYMENTS)/docker-compose.yml exec -it producer_dev /bin/bash



#-----------------------------------------------------------------------------



.PHONY: build_consumer
build_consumer:
	export CONTEXT=$(ROOT_DIR)/consumer_group
	export BROKER=$(KAFKA_IP_ONNETWORK):$(KAFKA_PORT_ONNETWORK)
	export COMMAND=/bin/bash
	export CONSUMER_ONNETWORK=$(CONSUMER1_ONNETWORK)
	docker-compose -f $(DEPLOYMENTS)/docker-compose.yml build consumer_group_dev


.PHONY: up_consumer
up_consumer: build_consumer
	export CONTEXT=$(ROOT_DIR)/consumer_group
	export BROKER=$(KAFKA_IP_ONNETWORK):$(KAFKA_PORT_ONNETWORK)
	export COMMAND=/bin/bash
	export CONSUMER_ONNETWORK=$(CONSUMER1_ONNETWORK)
	docker-compose --project-name $(PROJECT_NAME) -f $(DEPLOYMENTS)/docker-compose.yml --profile consumer up -d




.PHONY: bash_consumer
bash_consumer:
	docker-compose --project-name $(PROJECT_NAME) -f $(DEPLOYMENTS)/docker-compose.yml exec -it consumer_group_dev /bin/bash



#-----------------------------------------------------------------------------
# Now you enter into producer container
# $ make bash_broducer
# And enter twice ingo consumer container
# make bash_consumer
# make bash_consumer fom other host terminal session.
# Then do:
# go run ./				on both comsumer sessions.
# And then do
# go run ./ 			on producer session
# And you'll get load balancing.





#-----------------------------------------------------------------------------


.PHONY: cleanup
cleanup:
	docker compose -p $(PROJECT_NAME) down --volumes
#	docker compose -p $(PROJECT_NAME) down --volumes --rmi all
	/bin/bash $(DEPLOYMENTS)/remove_network.sh 










