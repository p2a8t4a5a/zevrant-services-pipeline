sed -i "s/\${POD_IP}/$POD_IP/g" ~/openssl.conf
sed -i "s/\${SERVICE_NAME}/$1/g" ~/openssl.conf
echo "$3"
if [[ "$3" != "" ]]; then
  echo "applying additional ip $ADDITIONAL_IP"
  echo "		IP.2 = $3" >> ~/openssl.conf
fi
cat ~/openssl.conf
openssl req -newkey rsa:4096 -nodes -keyout ~/private.pem -days 365 -out ~/public.csr -config ~/openssl.conf
username=$(aws secretsmanager get-secret-value --region us-east-1 --secret-id certificateUsername | jq .SecretString)
password=$(aws secretsmanager get-secret-value --region us-east-1 --secret-id certificatePassword | jq .SecretString)
username=$(echo "$username" | cut -c 2-$((${#username}-1)))
password=$(echo "$password" | cut -c 2-$((${#password}-1)))
certificateRequest=$(cat ~/public.csr)
certificateRequest=$(printf "%s" "$certificateRequest")
certificateRequest=$(echo "$certificateRequest" | cut -c 3-$((${#certificateRequest}-1)))
certificateRequest="{\"certificateRequest\":\"$certificateRequest\",\"ip\":\"$POD_IP\"}"
curl --insecure https://zevrant-01.zevrant-services.com:9009/zevrant-certificate-service/certs --data "$certificateRequest" --user "$username":"$password" -H "Content-Type: application/json" -X POST > ~/public.crt
openssl pkcs12 -export -inkey ~/private.pem -in ~/public.crt -passout "pass:$2" -out ~/zevrant-services.p12
rm ~/public.crt ~/private.pem ~/openssl.conf
