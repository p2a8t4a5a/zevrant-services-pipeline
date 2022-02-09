cp /root/openssl.conf.bak /root/openssl.conf
sed -i "s/\${SERVICE_NAME}/${1}.zevrant-services.com/g" ~/openssl.conf
cat /root/openssl.conf
openssl req -newkey rsa:4096 -nodes -keyout ~/private.pem -days 365 -out /root/public.csr -config /root/openssl.conf
username=$(aws secretsmanager get-secret-value --region us-east-1 --secret-id certificateUsername | jq .SecretString)
password=$(aws secretsmanager get-secret-value --region us-east-1 --secret-id certificatePassword | jq .SecretString)
username=$(echo "$username" | cut -c 2-$((${#username}-1)))
password=$(echo "$password" | cut -c 2-$((${#password}-1)))
certificateRequest=$(cat /root/public.csr)
certificateRequest=$(printf "%q" "$certificateRequest")
certificateRequest=$(echo "$certificateRequest" | cut -c 3-$((${#certificateRequest}-1)))
certificateRequest="{\"certificateRequest\":\"$certificateRequest\",\"ip\":\"${1}.zevrant-services.com}\"}"
curl --insecure https://zevrant-01.zevrant-services.com:9009/zevrant-certificate-service/certs --data "$certificateRequest" --user "$username":"$password" -H "Content-Type: application/json" -X POST > /root/public.crt
today="$(date --utc --iso-8601)"
mv /root/private.pem "/etc/pki/archive/${1}.zevrant-services.com-${today}.key"
mv /root/public.crt "/etc/pki/archive/${1}.zevrant-services.com-${today}.crt"
ln -s "/etc/pki/archive/${1}.zevrant-services.com-${today}.crt" "/etc/pki/archive/${1}.zevrant-services.com-${today}.key" /etc/pki/live
