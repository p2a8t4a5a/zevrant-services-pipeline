#!/bin/bash

source .env
cp docker-compose.yml docker-compose.yml.bak
sed -i "s/ACCESS_KEY_ID:/ACCESS_KEY_ID: $ACCESS_KEY_ID/g" docker-compose.yml
sed -i "s/SECRET_ACCESS_KEY:/SECRET_ACCESS_KEY: $SECRET_ACCESS_KEY/g" docker-compose.yml
sed -i "s~DB_ADDR:~DB_ADDR: $DB_ADDR~g" docker-compose.yml

podman-compose -f docker-compose.yml up -d --force-recreate
rm docker-compose.yml
mv docker-compose.yml.bak docker-compose.yml
