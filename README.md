# Building a Production-Ready Microservices Orchestration System

## Background & Objectives

Modern applications rarely exist as monolithic codebases. Instead, they are broken down into smaller, independent services — each responsible for a specific business function. This architectural approach, known as microservices, offers significant advantages: teams can develop and deploy services independently, scale specific components based on demand, and isolate failures to prevent the entire system from crashing.

However, this distributed nature introduces new challenges. Each microservice typically requires its own database, may need to communicate with other services, and must be accessible to end users through a unified interface. Managing this complexity manually is not only tedious but also error-prone.

This project tackles exactly these challenges. The goal was to build a production-ready e-commerce platform consisting of seven microservices:

- **Gateway Service** — The main entry point routing requests to internal services
- **Session Service** — Handles user authentication and sessions
- **Payment Service** — Processes payments
- **Booking Service** — Manages hotel reservations
- **Loyalty Service** — Tracks customer loyalty points
- **Hotel Service** — Manages hotel inventory
- **Report Service** — Generates statistics and reports

The objective was to containerize these services, orchestrate them using Docker Compose for local development, and then scale to a multi-node Docker Swarm cluster for production-like deployment.

---

## Solution Architecture

### High-Level Overview

The system follows a layered architecture designed for scalability and maintainability:

```
┌─────────────────────────────────────────────────────────────┐
│                        Client                               │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTP (Port 80)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     Nginx Reverse Proxy                     │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────────┐
│                   Gateway Service (8087)                  │
│         (Routes requests to internal microservices)       │
└──────┬────────┬─────────┬─────────┬─────────┬───────┬─────┘
       │        │         │         │         │       │      
   ┌───┴───┐ ┌──┴────┐ ┌──┴────┐ ┌──┴────┐ ┌──┴──┐ ┌──┴───┐
   │Session│ │Payment│ │Loyalty│ │Booking│ │Hotel│ │Report│
   │  8081 │ │  8084 │ │  8085 │ │  8083 │ │8082 │ │ 8086 │
   └──┬────┘ └──┬────┘ └──┬────┘ └──┬────┘ └──┬──┘ └──┬───┘
      │         │         │         │         │       │
      └─────────┴─────────┴─────────┴─────────┴───────┘
                             │
             ┌───────────────┴───────────────┐
             ▼                               ▼
    ┌─────────────────┐             ┌─────────────────┐
    │   PostgreSQL    │             │     RabbitMQ    │
    │   (Database)    │             │  (Message Queue)│
    └─────────────────┘             └─────────────────┘
```

### Infrastructure Components

- **PostgreSQL** — Centralized relational database for persistent data
- **RabbitMQ** — Message broker for asynchronous communication between services
- **Nginx** — Reverse proxy providing unified access point and path-based routing
- **Docker Swarm** — Container orchestration with 3 nodes (1 manager + 2 workers)

---

## Implementation

### Part 1: Docker Compose for Local Development

#### Dockerfiles for Each Microservice

Each Java-based microservice uses a multi-stage Docker build to keep the final image lean:

```dockerfile
FROM eclipse-temurin:8-jdk-alpine AS build
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache ca-certificates openssl maven bash
RUN update-ca-certificates

# Build the application
COPY pom.xml ./
COPY src ./src
RUN mvn -B -DskipTests package

# Runtime image
FROM eclipse-temurin:8-jre-alpine
WORKDIR /app
COPY wait-for-it.sh .
RUN chmod +x wait-for-it.sh
COPY --from=build /app/target/*.jar app.jar

ENTRYPOINT ["sh", "-c", "./wait-for-it.sh -s -t 120 postgres:5432 && \
                        ./wait-for-it.sh -s -t 120 rabbitmq:5672 && \
                        exec java -jar app.jar"]
```

The multi-stage approach separates the build environment (with Maven) from the runtime environment (lightweight JRE), significantly reducing image size.

#### Docker Compose Configuration

The `docker-compose.yml` defines all services with their dependencies, environment variables, and networking:

```yaml
services:
  postgres:
    image: "postgres:15.1-alpine"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: default_database
    networks:
      - internal-network

  nginx:
    image: nginx:latest
    ports:
      - "80:80"
    configs:
      - source: nginx_conf
        target: /etc/nginx/nginx.conf
    networks:
      - internal-network

  gateway:
    image: sulaiman3352/gateway-service:latest
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/users_db
      SESSION_SERVICE_HOST: session
      SESSION_SERVICE_PORT: 8081
      # ... other service configurations
    depends_on:
      - postgres
      - session
    networks:
      - internal-network
```

#### Handling Service Dependencies

One common challenge with containerized microservices is service startup order. Databases and message queues must be ready before application services attempt to connect. The `wait-for-it.sh` script solves this by blocking until dependencies are available:

```bash
./wait-for-it.sh -s -t 120 postgres:5432 && \
./wait-for-it.sh -s -t 120 rabbitmq:5672 && \
exec java -jar app.jar
```

#### Building and Running

```bash
DOCKER_BUILDKIT=0 docker compose build
docker compose up -d
```

After successful deployment, all services become accessible locally, with gateway on port 8087 and session service on port 8081.

---

### Part 2: Virtual Machines with Vagrant

#### Why Virtual Machines?

While Docker Compose works beautifully for local development, production environments run on dedicated machines — physical or virtual. To simulate this realistically, Vagrant provides an easy way to create and manage virtual machines.

#### Vagrant Configuration

The `Vagrantfile` defines three virtual machines:

```ruby
Vagrant.configure("2") do config|
  config.vm.box = "cloud-image/ubuntu-24.04"
  
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = "2"
  end

  config.vm.define "manager01" do |manager|
    manager.vm.hostname = "manager01"
    manager.vm.network "private_network", ip: "192.168.56.10"
    manager.vm.provision "shell", path: "./02/setup.sh"
  end

  config.vm.define "worker01" do |worker|
    worker.vm.hostname = "worker01"
    worker.vm.network "private_network", ip: "192.168.56.11"
  end

  config.vm.define "worker02" do |worker|
    worker.vm.hostname = "worker02"
    worker.vm.network "private_network", ip: "192.168.56.12"
  end
end
```

#### Automated Docker Installation

The `setup.sh` script automatically installs Docker on each VM:

```bash
# Add Docker's official GPG key
sudo apt update
sudo apt install ca-certificates curl -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

# Install Docker
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Allow vagrant user to run Docker
sudo usermod -aG docker vagrant

# Configure Docker daemon for Swarm compatibility
mkdir -p /etc/docker
echo '{ "min-api-version": "1.24" }' | sudo tee /etc/docker/daemon.json
```

---

### Part 3: Docker Swarm Cluster

#### Initializing the Swarm

Docker Swarm transforms a group of Docker hosts into a single, virtual Docker host. The manager node orchestrates the cluster, while worker nodes execute tasks.

```bash
# On manager01
docker swarm init --advertise-addr 192.168.56.10

# Save worker join token for other nodes
docker swarm join-token -q worker > /home/vagrant/03/swarm_token
```

#### Creating Overlay Network

For services running on different nodes to communicate, we need an overlay network:

```bash
docker network create \
  --driver overlay \
  --attachable \
  myapp_internal-network
```

The `--attachable` flag allows standalone containers to attach to the overlay network, useful for debugging.

#### Worker Nodes Joining

Worker nodes read the join token from the shared folder and join the cluster:

```bash
# On worker01 and worker02
TOKEN=$(cat /home/vagrant/03/swarm_token)
docker swarm join --advertise-addr 192.168.56.11 --token "$TOKEN" 192.168.56.10:2377
```

#### Deploying the Stack

Once the cluster is ready, services are deployed as a stack:

```bash
docker stack deploy -c docker-compose.yml myapp
```

The Docker Compose file is designed for Swarm mode, using `deploy` configurations for replication and placement constraints:

```yaml
gateway:
  image: sulaiman3352/gateway-service:latest
  deploy:
    replicas: 1
    placement:
      constraints: [node.role == manager]
```

#### Nginx Reverse Proxy Configuration

The Nginx configuration routes traffic based on URL path:

```nginx
server {
    listen 80;

    location /gateway/ {
        rewrite ^/gateway/(.*) /$1 break;
        proxy_pass http://gateway:8087;
    }

    location /session/ {
        rewrite ^/session/(.*) /$1 break;
        proxy_pass http://session:8081;
    }
}
```

This allows users to access services through a single endpoint (port 80), while the services themselves remain inaccessible directly from the outside.

---

## Monitoring with Portainer

Managing containers across multiple nodes can become challenging without visual tools. Portainer provides a web-based interface to:

- View all containers across the cluster
- Monitor resource usage
- Visualize container distribution across nodes
- Manage stacks, services, and deployments

Portainer is deployed as a stack within the Swarm:

```bash
curl -L https://downloads.portainer.io/ce2-19/portainer-agent-stack.yml -o portainer-stack.yml
docker stack deploy -c portainer-stack.yml portainer
```

Once running, Portainer is accessible at `https://localhost:9443`.

---

## Challenges and Solutions

### Challenge 1: Service Startup Ordering

**Problem:** Microservices attempted to connect to PostgreSQL and RabbitMQ before they were ready, causing startup failures.

**Solution:** Implemented `wait-for-it.sh` — a script that polls service availability before starting the application. This ensures databases and message queues are fully initialized before services attempt connections.

### Challenge 2: Maven Build SSL/TLS Errors

**Problem:** Running Maven builds inside Alpine-based containers sometimes failed due to SSL certificate issues when downloading dependencies.

**Solution:** 
- Updated CA certificates with `update-ca-certificates`
- Configured HTTPS protocols explicitly: `-Dhttps.protocols=TLSv1.2`
- Added retry logic in the build process for transient network issues

### Challenge 3: Cross-Host Networking

**Problem:** Services running on different VMs couldn't communicate with each other.

**Solution:** Created an overlay network in Docker Swarm (`--driver overlay`). This network spans all nodes in the cluster, allowing containers to communicate using service names as hostnames.

### Challenge 4: Node Coordination

**Problem:** Worker nodes needed the join token from the manager, but VMs are created simultaneously.

**Solution:** Used Vagrant's synced folder feature to share a directory between the host and all VMs. The manager writes the token to this shared folder, and workers read it before joining.

### Challenge 5: Unified API Access

**Problem:** Each service exposed its own port, making it confusing for clients and potentially exposing internal services.

**Solution:** Configured Nginx as a reverse proxy with path-based routing. All traffic enters through port 80, and Nginx forwards requests to the appropriate internal service based on the URL path (`/gateway/`, `/session/`).

---

## Technologies Used

| Category | Technology |
|----------|------------|
| Container Runtime | Docker |
| Orchestration | Docker Compose, Docker Swarm |
| Virtualization | Vagrant, VirtualBox |
| Reverse Proxy | Nginx |
| Monitoring | Portainer |
| Database | PostgreSQL 15.1 |
| Message Queue | RabbitMQ |
| Build Tool | Maven |
| Runtime Environment | Eclipse Temurin (Java 8) |

---

## Conclusion

This project demonstrates the complete journey from containerizing individual microservices to orchestrating them in a production-like cluster environment. Starting with Docker Compose for local development, moving through Vagrant-provisioned virtual machines, and finally scaling to a Docker Swarm cluster with three nodes, the solution addresses real-world challenges in distributed system deployment.

Key takeaways include understanding service dependencies, managing cross-host networking, implementing proper load balancing, and leveraging visualization tools for cluster monitoring. These skills form the foundation for any DevOps or cloud-native development role.
