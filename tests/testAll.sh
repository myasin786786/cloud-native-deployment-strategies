#!/usr/bin/env bash

echo $2
echo $2
echo $3
echo ¡¡blue-green-pipeline!!
cd ../blue-green-pipeline/util
./test.sh $1 $2 no $3
sleep 1m
cd ../../blue-green-pipeline/util
./delete.sh

sleep 30s
echo ¡¡blue-green-argo-rollouts!!
cd ../../blue-green-argo-rollouts/util
./test.sh no $2 no
sleep 1m
cd ../../blue-green-argo-rollouts/util
./delete.sh

sleep 30s
echo ¡¡canary-argo-rollouts!!
cd ../../canary-argo-rollouts/util
./test.sh no $2 no
sleep 1m
cd ../../canary-argo-rollouts/util
./delete.sh

sleep 30s
echo ¡¡canary-service-mesh!!
cd ../../canary-service-mesh/util
./test.sh no $2 no $4
sleep 1m
cd ../../canary-service-mesh/util
./delete.sh
