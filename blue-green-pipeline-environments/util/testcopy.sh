#!/usr/bin/env bash

user=user11
token=$1
funcPull()
{
    pull_number=$(curl -H "Accept: application/vnd.github+json"   -H "Authorization: Bearer $token"   https://api.github.com/repos/davidseve/cloud-native-deployment-strategies/pulls | jq -r '.[0].number')
    curl \
    -X PUT \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $token" \
    https://api.github.com/repos/davidseve/cloud-native-deployment-strategies/pulls/$pull_number/merge \
    -d '{"commit_title":"Expand enum","commit_message":"Add a new value to the merge_method enum"}'
}

# oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-
# Add Argo CD Git Webhook to make it faster

rm -rf /tmp/deployment
mkdir /tmp/deployment
cd /tmp/deployment

git clone https://github.com/davidseve/cloud-native-deployment-strategies.git
cd cloud-native-deployment-strategies
#To work with a branch that is not main. ./test.sh ghp_JGFDSFIGJSODIJGF no helm_base
if [ ${3:-no} != "no" ]
then
    git checkout $3
fi
git checkout -b release
git push origin release









sed -i 's/change_me/davidseve/g' blue-green-pipeline-environments/applicationset-shop-blue-green.yaml
sed -i "s/user1/$user/g" blue-green-pipeline-environments/applicationset-shop-blue-green.yaml
sed -i "s/user1/$user/g" blue-green-pipeline-environments/pipelines/run-products-stage/*
sed -i "s/user1/$user/g" blue-green-pipeline-environments/pipelines/run-products-prod/*

oc login -u $user -p openshift $4

oc apply -f blue-green-pipeline-environments/applicationset-shop-blue-green.yaml --wait=true

export TOKEN=$1
export GIT_USER=davidseve
oc create secret generic github-token --from-literal=username=${GIT_USER} --from-literal=password=${TOKEN} --type "kubernetes.io/basic-auth" -n $user-continuous-deployment
oc annotate secret github-token "tekton.dev/git-0=https://github.com/davidseve" -n $user-continuous-deployment
oc secrets link pipeline github-token -n $user-continuous-deployment


cd blue-green-pipeline-environments/pipelines/run-products-stage
namespace=$user-stage
while [[ "$namespace" != "exit" ]]
do
    tkn pipeline start pipeline-blue-green-e2e-test --param NEW_IMAGE_TAG=v1.0.1 --param MODE=online --param LABEL=.version --param APP=products --param NAMESPACE=$namespace  --param MESH=False --param JQ_PATH=.metadata --workspace name=app-source,claimName=workspace-pvc-shop-cd-e2e-tests -n $user-continuous-deployment --showlog

    
    oc create -f 1-pipelinerun-products-new-version.yaml -n $user-continuous-deployment
    sleep 2m
    funcPull

    oc get service products-umbrella-offline -n $namespace --output="jsonpath={.spec.selector.version}" > color
    replicas=-1
    while [ $replicas != 2 ]
    do
        sleep 5
        replicas=$(oc get deployments products-$(cat color) -n $namespace --output="jsonpath={.spec.replicas}" 2>&1)
        echo $replicas

    done

    tkn pipeline start pipeline-blue-green-e2e-test --param NEW_IMAGE_TAG=online --param MODE=offline --param LABEL=.mode --param APP=products --param NAMESPACE=$namespace  --param MESH=False --param JQ_PATH=.products[0].discountInfo.metadata --workspace name=app-source,claimName=workspace-pvc-shop-cd-e2e-tests -n $user-continuous-deployment --showlog
    tkn pipeline start pipeline-blue-green-e2e-test --param NEW_IMAGE_TAG=v1.1.1 --param MODE=offline --param LABEL=.version --param APP=products --param NAMESPACE=$namespace  --param MESH=False --param JQ_PATH=.metadata --workspace name=app-source,claimName=workspace-pvc-shop-cd-e2e-tests -n $user-continuous-deployment --showlog


    oc create -f 2-pipelinerun-products-switch.yaml -n $user-continuous-deployment
    sleep 3m
    funcPull
    tkn pipeline start pipeline-blue-green-e2e-test --param NEW_IMAGE_TAG=v1.1.1 --param MODE=online --param LABEL=.version --param APP=products --param NAMESPACE=$namespace  --param MESH=False --param JQ_PATH=.metadata --workspace name=app-source,claimName=workspace-pvc-shop-cd-e2e-tests -n $user-continuous-deployment --showlog

    #Rollback
    oc create -f 2-pipelinerun-products-switch-rollback.yaml -n $user-continuous-deployment
    sleep 2m
    funcPull
    tkn pipeline start pipeline-blue-green-e2e-test --param NEW_IMAGE_TAG=v1.0.1 --param MODE=online --param LABEL=.version --param APP=products --param NAMESPACE=$namespace  --param MESH=False --param JQ_PATH=.metadata --workspace name=app-source,claimName=workspace-pvc-shop-cd-e2e-tests -n $user-continuous-deployment --showlog


    oc create -f 2-pipelinerun-products-switch.yaml -n $user-continuous-deployment
    sleep 3m
    funcPull
    tkn pipeline start pipeline-blue-green-e2e-test --param NEW_IMAGE_TAG=v1.1.1 --param MODE=online --param LABEL=.version --param APP=products --param NAMESPACE=$namespace  --param MESH=False --param JQ_PATH=.metadata --workspace name=app-source,claimName=workspace-pvc-shop-cd-e2e-tests -n $user-continuous-deployment --showlog


    oc create -f 3-pipelinerun-products-align-offline.yaml -n $user-continuous-deployment
    sleep 2m
    funcPull

    tkn pipeline start pipeline-blue-green-e2e-test --param NEW_IMAGE_TAG=online --param MODE=online --param LABEL=.mode --param APP=products --param NAMESPACE=$namespace  --param MESH=False --param JQ_PATH=.products[0].discountInfo.metadata --workspace name=app-source,claimName=workspace-pvc-shop-cd-e2e-tests -n $user-continuous-deployment --showlog
    tkn pipeline start pipeline-blue-green-e2e-test --param NEW_IMAGE_TAG=v1.1.1 --param MODE=offline --param LABEL=.version --param APP=products --param NAMESPACE=$namespace  --param MESH=False --param JQ_PATH=.metadata --workspace name=app-source,claimName=workspace-pvc-shop-cd-e2e-tests -n $user-continuous-deployment --showlog
    tkn pipeline start pipeline-blue-green-e2e-test --param NEW_IMAGE_TAG=v1.1.1 --param MODE=online --param LABEL=.version --param APP=products --param NAMESPACE=$namespace  --param MESH=False --param JQ_PATH=.metadata --workspace name=app-source,claimName=workspace-pvc-shop-cd-e2e-tests -n $user-continuous-deployment --showlog


    if [ $namespace = "$user-stage" ]
    then
        cd ..
        cd run-products-prod
        namespace=$user-prod
    else
        namespace=exit
    fi
    
    echo $namespace
done
