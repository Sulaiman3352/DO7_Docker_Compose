#!/bin/bash

set -e

echo "[INFO] Waiting for all nodes..."
sleep 15

echo "[INFO] Building images..."
cd /home/vagrant/dcompose/
export DOCKER_BUILDKIT=1

# Build images using docker compose
docker compose build

echo "[INFO] Tagging images for Swarm..."
# Tag each service with a simple name that matches docker-compose.yml
docker tag dcompose-session:latest session:latest
docker tag dcompose-gateway:latest gateway:latest
docker tag dcompose-hotel:latest hotel:latest
docker tag dcompose-booking:latest booking:latest
docker tag dcompose-payment:latest payment:latest
docker tag dcompose-loyalty:latest loyalty:latest
docker tag dcompose-report:latest report:latest

echo "[INFO] Deploying stack..."
docker stack deploy -c docker-compose.yml myapp

echo "[INFO] Deploying Portainer..."
curl -L https://downloads.portainer.io/ce2-19/portainer-agent-stack.yml -o portainer-stack.yml
docker stack deploy -c portainer-stack.yml portainer

sleep 10
echo "[INFO] Services deployed:"
docker service ls

echo "[INFO] Container distribution:"
docker node ps $(docker node ls -q)
