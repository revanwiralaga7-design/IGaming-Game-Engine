# Multi-stage Dockerfile for casino-engine

# ---- Build stage ----
FROM eclipse-temurin:21-jdk-alpine AS build

WORKDIR /src

# Copy Gradle wrapper and config first for better caching
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle/ gradle/

# Download dependencies (cached unless build files change)
RUN chmod +x gradlew && ./gradlew dependencies --no-daemon || true

# Copy source code
COPY src/ src/
COPY proto/ proto/ 2>/dev/null || true

# Build the distribution tar
RUN ./gradlew distTar --no-daemon

# ---- Runtime stage ----
FROM eclipse-temurin:21-jre-alpine

LABEL maintainer="NekGambling"
LABEL description="iGambling Game Core Service"

# Create non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy built distribution from build stage
COPY --from=build /src/build/distributions/casino-engine-*.tar /tmp/

# Extract and setup
RUN tar -xf /tmp/casino-engine-*.tar -C /app --strip-components=1 && \
    rm /tmp/casino-engine-*.tar && \
    chmod +x /app/bin/casino-engine && \
    chmod +x /app/bin/sync-aggregators && \
    chmod +x /app/bin/db-migrate && \
    chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose ports (HTTP and gRPC)
EXPOSE 80 5050