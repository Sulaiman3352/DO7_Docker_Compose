# Option 2: Using official Maven image
FROM maven:3.8-eclipse-temurin-8-alpine AS build

WORKDIR /app

RUN apk add --no-cache ca-certificates && update-ca-certificates

# Maven is already installed in this image
ENV MAVEN_OPTS="-Xmx2048m -Xms1024m -Dhttps.protocols=TLSv1.2"

# Copy POM for dependency caching
COPY pom.xml ./
RUN mvn -B -q dependency:go-offline

# Copy source and build
COPY src ./src
RUN mvn -B -DskipTests clean package

# Final lightweight image
FROM eclipse-temurin:8-jre-alpine

WORKDIR /app
RUN apk add --no-cache bash

COPY wait-for-it.sh ./
RUN chmod +x wait-for-it.sh

COPY --from=build /app/target/*.jar app.jar

ENTRYPOINT ["sh", "-c", "./wait-for-it.sh -s -t 60 postgres:5432 && \
                        ./wait-for-it.sh -s -t 60 rabbitmq:5672 && \
                        exec java -jar app.jar"]
