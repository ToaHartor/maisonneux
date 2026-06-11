# Priority classes

system-node-critical (2000001000) :

- cilium
- linstor
- nvidia
- spegel
- tuppr

system-cluster-critical (2000000000) :

- cilium-operator
- coredns
- descheduler
- metrics-server
- piraeus
- talos-ccm
- fluxcd

operators (100005000) :

- cloudnative-pg
- cnpg-barman
- dragonfly-operator
- external-secrets
- garage-operator

services-critical (100004000) :

- dragonfly-clulster
- garage-gateway
- zot

monitoring (100003000) :

- grafana-operator
- grafana-deployment
- opentelemetry
- victoria-metrics
- victoria-logs

services-important (100002000) :

- authentik
- crowdsec
- traefik
- vaultwarden
