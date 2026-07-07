# LLM Setup

Onyx as front/rag : <https://github.com/onyx-dot-app/onyx>

- OIDC
- Use external LLM deployment
- Outline wiki integration for documentation : <https://github.com/onyx-dot-app/onyx/pull/5284>

No service account possible as this is external deployment, so the integration must be bootstrapped with the GUI

## LLM deployment

- vLLM for model management/deployment : <https://docs.vllm.ai/en/stable/>
  - More performant than ollama, see which model fits with the hardware (very small)
  - Does not support GGUF, most popular format for domestic usage

-> Use llama.cpp and variants/forks depending

## MCP servers integration

- Toolhive to register all mcp servers (eg : <https://github.com/m00nwtchr/homelab-cluster/blob/master/kubernetes/apps/toolhive/toolhive/config/searxng.yaml> <https://github.com/rcdailey/home-ops/tree/main/kubernetes/apps/toolhive> )

Can be used at cluster level : <https://docs.stacklok.com/toolhive/guides-k8s/deploy-operator?method=helm#cluster-mode-default>

Since our AI and MCP servers are in a different namespace than the apps, we must retrieve the secret via externalsecrets (or deploy the mcp server directly in the media namespace ?)

What is required ?

- ClusterSecretStores in media, services, monitoring namespaces (maybe a clustersecretstore for one secret is too much ?)
  - In the form of a Kustomize component ? We will not be able to use namespace selectors for security but in our context it does not matter much
  - -> Easier with a custom Helm chart

- Then replace secret store deployed in papra with a reference to the clustersecretstore
- Create mcp servers in the ai namespace
- Mcpgroup all credentials
- Single oauth endpoint for the tools

### MCP servers credentials

- Service accounts  (e.g grafana) : no problem there as long as we can bootstrap them
- Static api keys (e.g arr) : easy as well
- api keys of personal accounts : Since it is created on runtime, we can't really provision them

Find a way to "forward" them to the mcp server from Onyx when it needs an environment variable to work

Apparently this is not supported by toolhive, better have oidc support which can forward authentication

### Servers list

- arr mcp server <https://github.com/aplaceforallmystuff/mcp-arr>

- jellyseerr mcp ? <https://github.com/aserper/jellyseerr-mcp>
- karakeep config for ollama/openai tagging <https://docs.karakeep.app/configuration/different-ai-providers/>
  - Is account bound so we can't really bootstrap it automatically, just add it manually I think
- Grafana mcp server, requires a service account
  - A way to bootstrap a service account is by using the grafana operator <https://github.com/m00nwtchr/homelab-cluster/tree/master/kubernetes/apps/observability/grafana>

## Exposing LLM servers

Using LiteLLM :

- Supports OIDC
- Has tracking/spending capabilities
- API key management to expose LLM servers

### Calculate simple token cost

Separate in two costs : input tokens (read) and output token (write)

- input_token_speed (token/s) and output_token_speed (token/s) can be retrieved in llama.cpp logs
- card_power (W) can be retrieved in nvidia-smi during a request
- electricity_cost in currency/kWh depends on your bills

1. Convert card_power (W) to card_consumption (kWh) :

```text
card_consumption = card_power / 1000
```

2. Calculate the hourly_card_cost (currency/h) with electricity_cost :

```text
hourly_card_cost = card_consumption * electricity_cost
```

3. Turn input_token_speed and output_token_speed to token speed per hour, and get input_token_cost and output_token_cost using hourly_card_cost :

```text
input_token_speed_hour = input_token_speed * 3600
input_token_cost = hourly_card_cost / input_token_speed_hour

output_token_speed_hour = output_token_speed * 3600
output_token_cost = hourly_card_cost / output_token_speed_hour
```

For my personal setup :

- 900 tkn/s input, 30 tkn/s output
- RTX 5060Ti consuming 160W on request, 3W on idle (nvidia-smi)
- Electricity cost is about 0.1398€/kWh

1. `card_consumption = 160W / 1000 = 0.160kWh`
2. `hourly_card_cost = 0.160kWh * 0;1398€/kWh = 0,022368€/h`
3. `input_token_cost = 0.022368€/h / (900t/s * 3600s) = 0.000000007€/t` ; `output_token_cost = 0.022368€/h / (30t/s * 3600s) = 0.000000207€/t`
