#!/bin/bash

set -e

locked=1

region=eu-central-1

while [ $locked -ne 0 ]; do
    rm eks-kubeconfig || true
    echo "selecting random cluster"
    cluster=$(eksctl get clusters -r $region | grep cilium-ci | sort -R | head -n 1 | cut -f1)

    echo "getting kubeconfig for $cluster"
    eksctl utils write-kubeconfig $cluster --kubeconfig eks-kubeconfig -r $region

    echo "aquiring cluster lock"
    set +e
    export KUBECONFIG=eks-kubeconfig
    kubectl create -f lock.yaml

    kubectl annotate deployment lock lock=1
    locked=$?
    echo $locked
    set -e
done

echo "lock acquired on cluster $cluster"
echo $cluster > cluster-name

ng=$(eksctl get nodegroup --cluster $cluster -r $region -o json | jq -r '.[0].Name')
echo "scaling $cluster ng $ng to 2"
eksctl scale nodegroup -r $region --cluster $cluster -n $ng -N 2
