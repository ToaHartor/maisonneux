WORKSPACES=static k8s-production k8s-staging fluxcd-production fluxcd-staging
FLUX_ENVS=production staging
MAKEFLAGS += -rR

.PHONY: python-venv start-devenv stop-devenv local-git talos-img cluster-health use-context tools tf-plan tf-apply tf-init tf-destroy dry-renovate renovate restore $(WORKSPACES)

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

# Helm utilities
# --kubeconfig string
.PHONY: cluster-deps deploy-cluster uninstall-cluster

cluster-deps:
	rm -f helm/maisonneux/Chart.lock
	helm dependency build helm/maisonneux

# Helmfile commands with environments
# $(HELM_ENVS):
# # make deploy-cluster <env>
# ifeq (deploy-cluster,$(filter deploy-cluster,$(MAKECMDGOALS)))
# 	# helmfile apply -f helm/helmfile.yaml
# 	helmfile sync -f helm/helmfile.yaml --environment $@ --debug
# 	# helm upgrade --install --timeout 30m --namespace maisonneux --create-namespace --values helm/values/cluster.yaml maisonneux helm/maisonneux
# endif
# # make uninstall-cluster <env>
# ifeq (uninstall-cluster,$(filter uninstall-cluster,$(MAKECMDGOALS)))
# 	helmfile destroy -f helm/helmfile.yaml --environment $@
# 	# helm uninstall maisonneux --wait --timeout 20m --namespace maisonneux
# endif

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
ifeq (tf-upgrade,$(filter tf-upgrade,$(MAKECMDGOALS)))
	bash scripts/make/tf-upgrade.sh $@
endif
ifeq (tf-output,$(filter tf-output,$(MAKECMDGOALS)))
	bash scripts/make/tf-output.sh $@
endif
	