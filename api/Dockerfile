# Stage 1: Development dependencies
FROM node:18-alpine AS deps

WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install dependencies
RUN npm ci

# Stage 2: Production image
FROM node:18-alpine AS runner

# Set environment to production
ENV NODE_ENV=production

# Install curl for health checks and debugging
RUN apk add --no-cache curl

# Create app directory
WORKDIR /app

# Create a non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nodeapp && \
    mkdir -p /app/storage /app/temp /app/logs && \
    chown -R nodeapp:nodejs /app

# Copy dependency files
COPY --from=deps --chown=nodeapp:nodejs /app/node_modules ./node_modules
COPY --chown=nodeapp:nodejs . .

# Set volume mount points
VOLUME [ "/app/storage", "/app/temp", "/app/logs" ]

# Set proper permissions
USER nodeapp

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start the application
CMD ["node", "src/app.js"]