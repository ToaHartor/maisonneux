WORKSPACES=static k8s-production k8s-staging fluxcd-production fluxcd-staging
FLUX_ENVS=production staging
MAKEFLAGS += -rR

# Dev utilities
.PHONY: python-venv start-devenv stop-devenv local-git talos-img cluster-health use-context tools dry-renovate renovate $(WORKSPACES)

cluster-health:
	bash scripts/check_cluster_health.sh

talos-img:
	bash scripts/build_talos_img.sh

tools:
	bash scripts/install_tools.sh

local-git:
	bash scripts/init_local_dev_gitea.sh

stop-devenv:
	bash scripts/stop_devenv.sh

start-devenv:
	bash scripts/start_devenv.sh

python-venv:
	rm -rf .venv
	uv self update || curl -LsSf https://astral.sh/uv/install.sh | sh
	uv venv --seed --python 3.13
	uv pip install pip -r dev/dev-requirements.txt
	ansible-galaxy collection install ansibleguy.opnsense --force

# Renovate
renovate:
	sh scripts/run_renovate.sh

dry-renovate:
	sh scripts/run_renovate.sh --dry-run

# Cluster utilities
.PHONY: use-context restore upgrade-k8s upgrade-talos

# Use the right kubeconfig
$(FLUX_ENVS):
# make use-context <flux-env>
ifeq (use-context,$(filter use-context,$(MAKECMDGOALS)))
	bash scripts/make/use-context.sh $@
endif
# make restore <flux-env>
ifeq (restore,$(filter restore,$(MAKECMDGOALS)))
	@make use-context $@
	@echo "Restoring cluster $@"
	bash scripts/restore/restore.sh
endif

# make upgrade-k8s <flux-env>
ifeq (upgrade-k8s,$(filter upgrade-k8s,$(MAKECMDGOALS)))
	@make use-context $@
	@echo "Upgrading Kubernetes on $@ cluster"
	bash scripts/upgrade_k8s.sh $@
endif

# make upgrade-talos <flux-env>
ifeq (upgrade-talos,$(filter upgrade-talos,$(MAKECMDGOALS)))
	@make use-context $@
	@echo "Upgrading Talos on $@ cluster"
	bash scripts/upgrade_node_os.sh $@
endif

# Terraform utiliies
.PHONY: tf-workspaces tf-plan tf-apply tf-destroy tf-init tf-upgrade tf-output

tf-workspaces:
	bash scripts/make/tf-workspaces.sh

# Terraform commands, argument is workspaces, and commands are detected in ifeq filter
$(WORKSPACES):
# make tf-plan <ws>
ifeq (tf-plan,$(filter tf-plan,$(MAKECMDGOALS)))
	bash scripts/make/tf-plan.sh $@
endif

# make tf-apply <ws>
ifeq (tf-apply,$(filter tf-apply,$(MAKECMDGOALS)))
	bash scripts/make/tf-apply.sh $@
endif
# make tf-destroy <ws>
ifeq (tf-destroy,$(filter tf-destroy,$(MAKECMDGOALS)))
	bash scripts/make/tf-destroy.sh $@
endif
# make tf-init <ws>
ifeq (tf-init,$(filter tf-init,$(MAKECMDGOALS)))
	bash scripts/make/tf-init.sh $@
endif
# make tf-upgrade <ws>
ifeq (tf-upgrade,$(filter tf-upgrade,$(MAKECMDGOALS)))
	bash scripts/make/tf-upgrade.sh $@
endif
# make tf-output <ws>
ifeq (tf-output,$(filter tf-output,$(MAKECMDGOALS)))
	bash scripts/make/tf-output.sh $@
endif
	