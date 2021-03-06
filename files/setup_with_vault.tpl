#!/bin/sh
# Deploys a simple Apache webpage with variables from Vault.

apt-get -y update > /dev/null 2>&1
apt install -y apache2 > /dev/null 2>&1
apt install -y jq > /dev/null 2>&1

vault_address=${vault_address}

echo "Your Vault server can be found at $${vault_address}"

jwt_token=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F'  -H Metadata:true -s | jq -r .access_token)

resource_group=$(curl 'http://169.254.169.254/metadata/instance?api-version=2018-02-01'  -H Metadata:true -s | jq -r .compute.resourceGroupName)

subscription_id=$(curl 'http://169.254.169.254/metadata/instance?api-version=2018-02-01'  -H Metadata:true -s | jq -r .compute.subscriptionId)

vm_name=$(curl 'http://169.254.169.254/metadata/instance?api-version=2018-02-01'  -H Metadata:true -s | jq -r .compute.name)

vault_token=$(curl --silent --request POST \
  --data "{\"role\": \"dev-role\", \"jwt\": \"$${jwt_token}\", \"resource_group_name\": \"$${resource_group}\", \"vm_name\": \"$${vm_name}\", \"subscription_id\": \"$${subscription_id}\"}" \
  $${vault_address}/v1/auth/azure/login | \
  jq -r .auth.client_token)

echo "Your token is $${vault_token}"

title=$(curl --silent \
  --header "X-Vault-Token: $${vault_token}" \
  $${vault_address}/v1/secret/data/app1 |
  jq -r .data.data.title)

wotd=$(curl --silent \
  --header "X-Vault-Token: $${vault_token}" \
  $${vault_address}/v1/secret/data/app1 |
  jq -r .data.data.wotd)

echo "Your secret is $${title}"

cat << EOM > /var/www/html/index.html
<html>
  <head><title>$${title}!</title></head>
  <body style="background-image: linear-gradient(white,grey);">
  <center><img src="https://logos-download.com/wp-content/uploads/2016/04/UBS_logo_logotype_emblem.png" height=400 width=800></img></center>
  <h1>Value from Vault: $${wotd}</h1>
  <h2>Title from Vault: $${title}</h2>
  </body>
</html>
EOM

echo "Your demo is now ready."
