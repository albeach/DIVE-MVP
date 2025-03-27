# Stage 1: Development dependencies
FROM node:18-alpine AS deps

WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install dependencies
RUN npm ci

# Stage 2: Builder
FROM node:18-alpine AS builder

WORKDIR /app

# Copy dependencies
COPY --from=deps /app/node_modules ./node_modules

# First, copy i18n critical files specifically to ensure they're included
COPY next-i18next.config.js ./
COPY public/locales ./public/locales
COPY src/utils/i18n.ts ./src/utils/i18n.ts

# Now copy everything else
COPY . .

# Debug i18n config during build
RUN echo "i18n config file contents:" && cat next-i18next.config.js
RUN echo "Verifying i18n locale files:" && ls -la public/locales || echo "No locales found!"

# Ensure public directory exists
RUN mkdir -p ./public

# Set build environment variables
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_KEYCLOAK_URL
ARG NEXT_PUBLIC_KEYCLOAK_REALM
ARG NEXT_PUBLIC_KEYCLOAK_CLIENT_ID
ARG NEXT_PUBLIC_FRONTEND_URL

ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_KEYCLOAK_URL=$NEXT_PUBLIC_KEYCLOAK_URL
ENV NEXT_PUBLIC_KEYCLOAK_REALM=$NEXT_PUBLIC_KEYCLOAK_REALM
ENV NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=$NEXT_PUBLIC_KEYCLOAK_CLIENT_ID
ENV NEXT_PUBLIC_FRONTEND_URL=$NEXT_PUBLIC_FRONTEND_URL

# Update silent-check-sso.html with environment variables
RUN if [ -f ./public/silent-check-sso.html ]; then \
    sed -i "s|\${PUBLIC_FRONTEND_URL}|$NEXT_PUBLIC_FRONTEND_URL|g" ./public/silent-check-sso.html && \
    sed -i "s|\${PUBLIC_KEYCLOAK_URL}|$NEXT_PUBLIC_KEYCLOAK_URL|g" ./public/silent-check-sso.html && \
    sed -i "s|\${PUBLIC_API_URL}|$NEXT_PUBLIC_API_URL|g" ./public/silent-check-sso.html; \
    fi

# Build the Next.js app
RUN npm run build

# Stage 3: Runner
FROM node:18-alpine AS runner

WORKDIR /app

# Set environment to production
ENV NODE_ENV=production

# Install curl for healthcheck
RUN apk add --no-cache curl

# Add non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy necessary files
COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/next-i18next.config.js ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/server.js ./server.js
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Verify i18n config is present in final stage
RUN echo "Checking i18n config in runner stage:" && [ -f "next-i18next.config.js" ] && echo "next-i18next.config.js exists" || echo "next-i18next.config.js MISSING!"
RUN echo "Checking locales in runner stage:" && ls -la public/locales || echo "No locales directory found!"

# Set proper permissions
USER nextjs

# Expose port
EXPOSE 3000

# Set hostname for container
ENV HOSTNAME=0.0.0.0

# Start the application with our custom server
CMD ["node", "/app/server.js"]