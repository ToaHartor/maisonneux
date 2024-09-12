WORKSPACES=$(shell find terraform/terraform.tfstate.d/* -type d -exec basename {} \;)
MAKEFLAGS += -rR

.PHONY: talos-img cluster-health use-context tools tf-plan tf-apply tf-init tf-destroy $(WORKSPACES)

cluster-health:
	sh scripts/check_cluster_health.sh

talos-img:
	sh scripts/build_talos_img.sh

tools:
	sh scripts/install_tools.sh

use-context:
	@mkdir -p ~/.kube
	@mkdir -p ~/.talos
	@kubectl config delete-context admin@k8s
	@cp -rf tmp/talosconfig.yml ~/.talos/config
	@cp -rf tmp/kubeconfig.yml ~/.kube/config
	@chmod 700 ~/.kube/config
	@kubectl config use-context admin@k8s

# Helm utilities
# --kubeconfig string
.PHONY: cluster-deps deploy-cluster uninstall-cluster

cluster-deps:
	rm -f helm/maisonneux/Chart.lock
	helm dependency build helm/maisonneux

deploy-cluster:
	# helmfile apply -f helm/helmfile.yaml
	helmfile sync -f helm/helmfile.yaml
	# helm upgrade --install --timeout 30m --namespace maisonneux --create-namespace --values helm/values/cluster.yaml maisonneux helm/maisonneux

uninstall-cluster:
	helmfile destroy -f helm/helmfile.yaml
	# helm uninstall maisonneux --wait --timeout 20m --namespace maisonneux


.PHONY: tf-plan tf-apply tf-destroy tf-init tf-upgrade

# Terraform operations
tf-upgrade:
	@cd terraform && \
	tofu init -upgrade

# Terraform commands, argument is workspaces, and commands are detected in ifeq filter
$(WORKSPACES):
ifeq (tf-plan,$(filter tf-plan,$(MAKECMDGOALS)))
	@cd terraform && \
	tofu workspace select $@ && \
	tofu plan -out $@.tfplan -var-file='$@/config.tfvars'
endif
ifeq (tf-apply,$(filter tf-apply,$(MAKECMDGOALS)))
	@cd terraform && \
	tofu workspace select $@ && \
	tofu apply $@.tfplan
	@if [ "$@" = "k8s" ]; then \
		cd terraform && tofu output -raw talosconfig >../tmp/talosconfig.yml && tofu output -raw kubeconfig >../tmp/kubeconfig.yml; \
	fi
endif
ifeq (tf-destroy,$(filter tf-destroy,$(MAKECMDGOALS)))
	@cd terraform && \
	tofu workspace select $@ && \
	tofu apply -destroy
endif
ifeq (tf-init,$(filter tf-init,$(MAKECMDGOALS)))
	@cd terraform && \
	tofu workspace select $@ && \
	tofu init -lockfile=readonly
endif