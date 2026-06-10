# ── Stage 1: Build ──────────────────────────────────────────────────────────
# Use the official Maven image with Eclipse Temurin JDK 17 (Alpine-based = minimal)
FROM maven:3.9-eclipse-temurin-17-alpine AS builder

WORKDIR /build

# Copy dependency descriptors first — lets Docker cache the dependency
# download layer separately from your source code
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Now copy source and build the fat JAR
COPY src ./src
RUN mvn package -DskipTests -q

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
# Use a minimal JRE-only image — no compiler, no Maven, no build tools
FROM eclipse-temurin:17-jre-alpine

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
