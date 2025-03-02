#!/bin/bash

# Exit on any error
set -e

echo "Installing Sealed Secrets Controller..."

# Add Sealed Secrets Helm repository
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

# Install Sealed Secrets Controller
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --set fullnameOverride=sealed-secrets-controller

echo "Waiting for controller to be ready..."
kubectl wait --for=condition=available --timeout=90s deployment/sealed-secrets-controller -n kube-system

echo "Sealed Secrets Controller installed successfully!"