kong-restart:
	@echo "Restarting Kong with proper cleanup..."
	@./scripts/kong-restart.sh

kong-reset:
	@echo "Force resetting Kong (removes container)..."
	@./scripts/kong-force-reset.sh

kong-reset-full:
	@echo "Force resetting Kong with volume cleanup..."
	@./scripts/kong-force-reset.sh --with-volumes 