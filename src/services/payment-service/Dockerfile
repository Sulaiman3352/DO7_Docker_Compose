FROM eclipse-temurin:8-jdk-alpine AS build
WORKDIR /app

# CRITICAL: Update CA certificates and install necessary packages
RUN apk add --no-cache --update \
    ca-certificates \
    openssl \
    maven \
    bash && \
    update-ca-certificates

# Optional: Set Java cryptographic extensions for better SSL
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Copy pom.xml first for better layer caching
COPY pom.xml ./

# Try building with retry mechanism and specific TLS protocol
RUN mvn -B -q -DskipTests -Dhttps.protocols=TLSv1.2 dependency:go-offline || \
    (echo "First attempt failed, retrying..." && \
     sleep 10 && \
     mvn -B -q -DskipTests -Dhttps.protocols=TLSv1.2 dependency:go-offline)

COPY src ./src
RUN mvn -B -DskipTests -Dhttps.protocols=TLSv1.2 package

FROM eclipse-temurin:8-jre-alpine
WORKDIR /app

# Also update CA certs in runtime image
RUN apk add --no-cache --update \
    bash \
    ca-certificates && \
    update-ca-certificates

COPY wait-for-it.sh .
RUN chmod +x wait-for-it.sh

COPY --from=build /app/target/*.jar app.jar

ENTRYPOINT ["sh", "-c", "./wait-for-it.sh -s -t 120 postgres:5432 && \
                        ./wait-for-it.sh -s -t 120 rabbitmq:5672 && \
                        exec java -jar app.jar"]
