#!/usr/bin/env bash
set -euo pipefail

# ====== CONFIG (AppRole only) ======
: "${VAULT_ADDR:=http://127.0.0.1:8200}"       # override if needed
: "${VAULT_ROLE_ID:?set VAULT_ROLE_ID}"        # export before running
: "${VAULT_SECRET_ID:?set VAULT_SECRET_ID}"    # export before running
VAULT_MOUNT="${VAULT_MOUNT:-kv}"               # KV v2 mount
VAULT_AZ_PATH="${VAULT_AZ_PATH:-azure/sp}"     # kv/<this>
TF_BIN="${TF_BIN:-terraform}"                   # terraform binary

# ====== REQUIREMENTS ======
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl required"; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo "ERROR: jq required"; exit 1; }

# ====== 1) LOGIN (AppRole -> client token) ======
LOGIN_BODY=$(jq -n --arg r "$VAULT_ROLE_ID" --arg s "$VAULT_SECRET_ID" '{role_id:$r, secret_id:$s}')
LOGIN_JSON=$(curl --fail-with-body -sS -H 'Content-Type: application/json' \
  -d "$LOGIN_BODY" "$VAULT_ADDR/v1/auth/approle/login")
VAULT_TOKEN=$(jq -er '.auth.client_token' <<<"$LOGIN_JSON")

# ====== 2) READ KV v2: kv/azure/sp ======
AZ_JSON=$(curl --fail-with-body -sS -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/$VAULT_MOUNT/data/$VAULT_AZ_PATH")

ARM_TENANT_ID=$(jq -er '.data.data.tenant_id'         <<<"$AZ_JSON")
ARM_SUBSCRIPTION_ID=$(jq -er '.data.data.subscription_id' <<<"$AZ_JSON")
ARM_CLIENT_ID=$(jq -er '.data.data.client_id'         <<<"$AZ_JSON")
ARM_CLIENT_SECRET=$(jq -er '.data.data.client_secret' <<<"$AZ_JSON")

echo "[approle→vault→tf] Azure creds ok (tenant=${ARM_TENANT_ID:0:8}…, client_id=${ARM_CLIENT_ID:0:8}…)"

# ====== 3) RUN TERRAFORM (env only for this process) ======
exec env \
  ARM_TENANT_ID="$ARM_TENANT_ID" \
  ARM_SUBSCRIPTION_ID="$ARM_SUBSCRIPTION_ID" \
  ARM_CLIENT_ID="$ARM_CLIENT_ID" \
  ARM_CLIENT_SECRET="$ARM_CLIENT_SECRET" \
  TF_VAR_vault_addr="$VAULT_ADDR" \
  TF_VAR_vault_role_id="$VAULT_ROLE_ID" \
  TF_VAR_vault_secret_id="$VAULT_SECRET_ID" \
  "$TF_BIN" "$@"
