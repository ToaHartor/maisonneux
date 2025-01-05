{{/*Very good example from https://github.com/goauthentik/authentik/issues/10021
Parameters :
- ApplicationName
- RedirectUri
*/}}
{{- define "common.authentik_oidc" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: authentik-oidc
  namespace: {{ .Release.Namespace }}
data:
  authentik-oidc-{{ lower .ApplicationName }}.yaml: |
    version: 1
    metadata:
      labels:
        blueprints.goauthentik.io/description: 'Managed by Helm'
      name: authentik-blueprint
    entries:
      # Imports from system blueprints
      ## Scopes
      - model: authentik_blueprints.metaapplyblueprint
        attrs:
          identifiers:
            name: "System - OAuth2 Provider - Scopes"
          required: true
      ## Flows
      - model: authentik_blueprints.metaapplyblueprint
        attrs:
          identifiers:
            name: "Default - Provider authorization flow (explicit consent)"
          required: true
      - model: authentik_blueprints.metaapplyblueprint
        attrs:
          identifiers:
            name: "Default - Provider authorization flow (implicit consent)"
          required: true
      # Custom flow
      - id: default-authentication-flow
        identifiers:
          slug: default-authentication-flow
        attrs:
          designation: authentication
          name: UMW
          slug: default-authentication-flow
          title: UMW
        model: authentik_flows.flow
        state: present
      # OIDC
      - id: {{ lower .ApplicationName }}-oidc
        identifiers:
          name: {{ .ApplicationName }}
        model: authentik_providers_oauth2.oauth2provider
        state: present
        attrs:
          name: {{ lower .ApplicationName }}-oidc
          access_code_validity: minutes=1
          access_token_validity: minutes=5
          authentication_flow: !Find [authentik_flows.flow, [slug, default-authentication-flow]]
          authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-explicit-consent]]
          client_id: prout
          client_secret: pouet
          client_type: confidential
          include_claims_in_id_token: true
          issuer_mode: per_provider
          refresh_token_validity: days=30
          sub_mode: hashed_user_id
          redirect_uris: http://prout.com/pouet
          property_mappings:
            - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-openid]]
            - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-email]]
            - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-profile]]
        conditions: []
      - id: {{ lower .ApplicationName }}-oidc
        identifiers:
          name: {{ .ApplicationName }}
        model: authentik_core.application
        attrs:
          # meta_launch_url:
          # meta_icon:
          name: {{ .ApplicationName }}
          policy_engine_mode: any
          provider: !KeyOf {{ lower .ApplicationName }}-oidc
          slug: {{ lower .ApplicationName }}
        state: present
{{- end -}}