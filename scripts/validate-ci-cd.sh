#!/bin/bash
set -e

echo "🔍 Validating DIVE25 CI/CD Pipeline Configuration"
echo "=================================================="

# Check if GitHub workflow files exist
if [ -f ".github/workflows/enhanced-ci-cd.yaml" ]; then
  echo "✅ Enhanced CI/CD workflow file exists"
else
  echo "❌ Enhanced CI/CD workflow file not found!"
  exit 1
fi

# Validate workflow yaml syntax
echo -n "Validating GitHub Actions workflow syntax..."
if command -v actionlint >/dev/null 2>&1; then
  actionlint .github/workflows/enhanced-ci-cd.yaml >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "✅"
  else
    echo "❌"
    echo "Workflow file has syntax issues. Install actionlint and run:"
    echo "actionlint .github/workflows/enhanced-ci-cd.yaml"
    exit 1
  fi
else
  echo "⚠️  (skipped - actionlint not installed)"
  echo "For comprehensive validation, install actionlint:"
  echo "  go install github.com/rhysd/actionlint/cmd/actionlint@latest"
fi

# Check for existence of necessary scripts
echo "Checking for required scripts..."
required_scripts=(
  "scripts/wait-for-services.sh"
  "scripts/post-deployment-test.sh"
  "scripts/smoke-test.sh"
)

for script in "${required_scripts[@]}"; do
  if [ -f "$script" ]; then
    echo "✅ $script exists"
    
    # Check if script is executable
    if [ -x "$script" ]; then
      echo "  ✅ $script is executable"
    else
      echo "  ❌ $script is not executable. Fix with:"
      echo "     chmod +x $script"
      exit 1
    fi
    
    # Basic syntax check for shell scripts
    bash -n "$script"
    if [ $? -eq 0 ]; then
      echo "  ✅ $script syntax is valid"
    else
      echo "  ❌ $script has syntax errors!"
      exit 1
    fi
  else
    echo "❌ $script not found!"
    exit 1
  fi
done

# Check for Docker Compose test file
if [ -f "docker-compose.test.yml" ]; then
  echo "✅ docker-compose.test.yml exists"
  
  # Validate docker-compose syntax if docker-compose is installed
  if command -v docker-compose >/dev/null 2>&1; then
    echo -n "  Validating docker-compose syntax..."
    docker-compose -f docker-compose.test.yml config >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "✅"
    else
      echo "❌"
      echo "  docker-compose.test.yml has syntax issues!"
      exit 1
    fi
  else
    echo "  ⚠️  (docker-compose validation skipped - docker-compose not installed)"
  fi
else
  echo "❌ docker-compose.test.yml not found!"
  exit 1
fi

# Check for end-to-end test configuration
if [ -d "e2e" ]; then
  echo "✅ e2e directory exists"
  
  if [ -f "e2e/playwright.config.js" ]; then
    echo "✅ playwright.config.js exists"
  else
    echo "❌ playwright.config.js not found in e2e directory!"
    exit 1
  fi
  
  if [ -f "e2e/package.json" ]; then
    echo "✅ e2e/package.json exists"
    
    # Check for required scripts in package.json
    if grep -q "\"test:e2e\":" "e2e/package.json" && grep -q "\"test:uat\":" "e2e/package.json"; then
      echo "✅ e2e/package.json contains required test scripts"
    else
      echo "❌ e2e/package.json missing required test scripts!"
      exit 1
    fi
  else
    echo "❌ package.json not found in e2e directory!"
    exit 1
  fi
else
  echo "❌ e2e directory not found!"
  exit 1
fi

# Check for performance tests
if [ -d "performance" ]; then
  echo "✅ performance directory exists"
  
  if [ -f "performance/scripts/api-load-test.js" ]; then
    echo "✅ api-load-test.js exists"
  else
    echo "❌ api-load-test.js not found in performance/scripts directory!"
    exit 1
  fi
  
  if [ -d "performance/results" ]; then
    echo "✅ performance/results directory exists"
  else
    echo "❌ results directory not found in performance directory!"
    exit 1
  fi
else
  echo "❌ performance directory not found!"
  exit 1
fi

# Check K8s directory structure (if using Kubernetes)
if [ -d "k8s" ]; then
  echo "✅ k8s directory exists"
  
  required_k8s_dirs=(
    "k8s/environments/development"
    "k8s/environments/staging"
    "k8s/environments/production"
  )
  
  for dir in "${required_k8s_dirs[@]}"; do
    if [ -d "$dir" ]; then
      echo "✅ $dir directory exists"
      
      # Check for kustomization.yaml in environment directory
      if [ -f "$dir/kustomization.yaml" ]; then
        echo "  ✅ $dir/kustomization.yaml exists"
      else
        echo "  ❌ kustomization.yaml not found in $dir!"
        exit 1
      fi
    else
      echo "❌ $dir directory not found!"
      exit 1
    fi
  done
else
  echo "⚠️  k8s directory not found! (Required for Kubernetes deployments)"
fi

# Documentation check
if [ -f "docs/deployment/ci-cd.md" ]; then
  echo "✅ CI/CD documentation exists"
else
  echo "❌ CI/CD documentation not found at docs/deployment/ci-cd.md!"
  exit 1
fi

# Final success message
echo ""
echo "✅ All CI/CD pipeline components validated successfully!"
echo "The DIVE25 CI/CD pipeline is configured correctly."
echo ""
echo "Next steps:"
echo "1. Ensure your GitHub repository has the required secrets configured"
echo "2. Set up branch protection rules for main and develop branches"
echo "3. Create the required directories in k8s/environments if deploying to Kubernetes"
echo "4. Configure alerting and notifications for pipeline events"
echo ""
echo "For more information, see docs/deployment/ci-cd.md" 