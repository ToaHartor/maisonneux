WORKSPACES=static k8s fluxcd-production fluxcd-staging
HELM_ENVS=dev prod
MAKEFLAGS += -rR

.PHONY: start-devenv stop-devenv local-git talos-img cluster-health use-context tools tf-plan tf-apply tf-init tf-destroy dry-renovate renovate $(WORKSPACES)

cluster-health:
	sh scripts/check_cluster_health.sh

talos-img:
	sh scripts/build_talos_img.sh

tools:
	sh scripts/install_tools.sh

local-git:
	sh scripts/init_local_dev_gitea.sh

stop-devenv:
	sh scripts/stop_devenv.sh

start-devenv:
	sh scripts/start_devenv.sh

# Renovate
renovate:
	sh scripts/run_renovate.sh

dry-renovate:
	sh scripts/run_renovate.sh --dry-run

use-context:
	@mkdir -p ~/.kube
	@mkdir -p ~/.talos
	@kubectl config delete-context admin@k8s || true
	@cp -rf tmp/talosconfig.yaml ~/.talos/config
	@cp -rf tmp/kubeconfig.yaml ~/.kube/config
	@chmod 700 ~/.kube/config
	@kubectl config use-context admin@k8s

# Helm utilities
# --kubeconfig string
.PHONY: cluster-deps deploy-cluster uninstall-cluster

cluster-deps:
	rm -f helm/maisonneux/Chart.lock
	helm dependency build helm/maisonneux

# Helmfile commands with environments
$(HELM_ENVS):
# make deploy-cluster <env>
ifeq (deploy-cluster,$(filter deploy-cluster,$(MAKECMDGOALS)))
	# helmfile apply -f helm/helmfile.yaml
	helmfile sync -f helm/helmfile.yaml --environment $@ --debug
	# helm upgrade --install --timeout 30m --namespace maisonneux --create-namespace --values helm/values/cluster.yaml maisonneux helm/maisonneux
endif
# make uninstall-cluster <env>
ifeq (uninstall-cluster,$(filter uninstall-cluster,$(MAKECMDGOALS)))
	helmfile destroy -f helm/helmfile.yaml --environment $@
	# helm uninstall maisonneux --wait --timeout 20m --namespace maisonneux
endif

.PHONY: tf-plan tf-apply tf-destroy tf-init tf-upgrade tf-output

# Terraform commands, argument is workspaces, and commands are detected in ifeq filter
$(WORKSPACES):
# make tf-plan <ws>
ifeq (tf-plan,$(filter tf-plan,$(MAKECMDGOALS)))
	sh scripts/make/tf-plan.sh $@
endif

# make tf-apply <ws>
ifeq (tf-apply,$(filter tf-apply,$(MAKECMDGOALS)))
	sh scripts/make/tf-apply.sh $@
endif
# make tf-destroy <ws>
ifeq (tf-destroy,$(filter tf-destroy,$(MAKECMDGOALS)))
	sh scripts/make/tf-destroy.sh $@
endif
# make tf-init <ws>
ifeq (tf-init,$(filter tf-init,$(MAKECMDGOALS)))
	sh scripts/make/tf-init.sh $@
endif
ifeq (tf-upgrade,$(filter tf-upgrade,$(MAKECMDGOALS)))
	sh scripts/make/tf-upgrade.sh $@
endif
ifeq (tf-output,$(filter tf-output,$(MAKECMDGOALS)))
	sh scripts/make/tf-output.sh $@
endif
	