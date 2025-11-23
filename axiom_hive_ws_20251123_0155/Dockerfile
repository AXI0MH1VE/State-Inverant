# Multi-stage Dockerfile for Axiom Hive

# Stage 1: Build Go services
FROM golang:1.21-alpine AS go-builder

WORKDIR /app

# Copy go mod files
COPY services/go.mod services/go.sum ./
RUN go mod download

# Copy source code
COPY services/ .

# Build all services
RUN go build -o /bin/gateway ./service-gateway
RUN go build -o /bin/guardian-legal ./service-guardians/guardian-legal
RUN go build -o /bin/guardian-safety ./service-guardians/guardian-safety
RUN go build -o /bin/guardian-audit ./service-guardians/guardian-audit
RUN go build -o /bin/drone ./service-drones

# Stage 2: Build Next.js frontend
FROM node:18-alpine AS frontend-builder

WORKDIR /app

COPY web/package*.json ./
RUN npm ci --only=production

COPY web/ .
RUN npm run build

# Stage 3: Runtime
FROM alpine:latest

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Copy Go binaries
COPY --from=go-builder /bin/gateway /usr/local/bin/
COPY --from=go-builder /bin/guardian-legal /usr/local/bin/
COPY --from=go-builder /bin/guardian-safety /usr/local/bin/
COPY --from=go-builder /bin/guardian-audit /usr/local/bin/
COPY --from=go-builder /bin/drone /usr/local/bin/

# Copy Next.js build
COPY --from=frontend-builder /app/.next /app/.next
COPY --from=frontend-builder /app/public /app/public
COPY --from=frontend-builder /app/package.json /app/package.json

# Change ownership
RUN chown -R nextjs:nodejs /app
USER nextjs

# Expose ports
EXPOSE 3000 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

# Start command (assuming a startup script)
CMD ["/usr/local/bin/gateway"]
