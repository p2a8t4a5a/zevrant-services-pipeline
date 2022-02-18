sed -i "s/\${POD_IP}/$POD_IP/g" ~/openssl.conf
sed -i "s/\${SERVICE_NAME}/$1/g" ~/openssl.conf
echo "$3"
if [[ "$3" != "" ]]; then
  echo "applying additional ip $ADDITIONAL_IP"
  echo "		IP.2 = $3" >> ~/openssl.conf
fi
cat ~/openssl.conf

VAULT_ADDR="https://develop.vault.zevrant-services.com"

if [[ "$ENVIRONMENT" == "prod" ]]; then
  VAULT_ADDR="https://vault.zevrant-services.com"
fi

openssl req -newkey rsa:4096 -nodes -keyout ~/private.pem -days 365 -out ~/public.csr -config ~/openssl.conf
token=$(curl ${VAULT_ADDR}/v1/auth/develop/login/$ACCESS_KEY_ID -X POST --data "{\"password\": \"$SECRET_ACCESS_KEY\"}" --fail)
token=$(echo "$token" | jq .auth.client_token)
token=$(echo "$token" | cut -c 2-$((${#token}-1)))
username=$(curl --header "X-Vault-token: $token" "${VAULT_ADDR}/v1/${ENVIRONMENT}/data/certificate/username" --fail)
username=$(echo "$username" | jq .data.data.value)
username=$(echo "$username" | cut -c 2-$((${#username}-1)))
password=$(curl --header "X-Vault-token: $token" "${VAULT_ADDR}/v1/${ENVIRONMENT}/data/certificate/username" --fail)
password=$(echo "$password" | jq .data.data.value)
password=$(echo "$password" | cut -c 2-$((${#password}-1)))
certificateRequest=$(cat ~/public.csr)
certificateRequest=$(printf "%q" "$certificateRequest")
certificateRequest=$(echo "$certificateRequest" | cut -c 3-$((${#certificateRequest}-1)))
certificateRequest="{\"certificateRequest\":\"$certificateRequest\",\"ip\":\"$POD_IP\"}"
curl --insecure https://zevrant-01.zevrant-services.com:9009/zevrant-certificate-service/certs --data "$certificateRequest" --user "$username":"$password" -H "Content-Type: application/json" -X POST > ~/public.crt
cat ~/public.crt
openssl pkcs12 -export -inkey ~/private.pem -in ~/public.crt -passout "pass:$2" -out ~/zevrant-services.p12
rm ~/public.crt ~/private.pem ~/openssl.conf
