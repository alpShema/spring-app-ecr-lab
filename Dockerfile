# ── Stage 1: Build ──────────────────────────────────────────────────────────
# Amazon Corretto 17 — AWS-maintained OpenJDK distribution, Alpine-based = minimal
FROM amazoncorretto:17-alpine AS builder

WORKDIR /build

# Install Maven (Corretto image ships JDK only, not Maven)
RUN apk add --no-cache maven

# Copy dependency descriptors first — lets Docker cache the dependency
# download layer separately from your source code
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Now copy source and build the fat JAR
COPY src ./src
RUN mvn package -DskipTests -q

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
# Corretto 17 JRE-only image — no compiler, no Maven, no build tools
FROM amazoncorretto:17-alpine

WORKDIR /app

# Create a non-root user for security — never run as root inside a container
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy only the compiled JAR from the build stage — nothing else
COPY --from=builder /build/target/*.jar app.jar

# Switch to non-root user before running the app
USER appuser

# Document the port the app listens on
EXPOSE 8080

# Run the JAR — use exec form (JSON array) so signals are passed correctly
ENTRYPOINT ["java", "-jar", "app.jar"]
