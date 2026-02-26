#!/bin/bash

cd /home/vagrant/dcompose/
echo "Starting Docker Compose build..."
sudo docker stack deploy -c docker-compose.yml myapp


