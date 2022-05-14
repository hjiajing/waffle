#!/bin/bash

set -e

KUBECONFIG_PATH="/Users/jiajinghu/.kube"
LEADER_CONFIG=${KUBECONFIG_PATH}/leader
WEST_CONFIG=${KUBECONFIG_PATH}/west
EAST_CONFIG=${KUBECONFIG_PATH}/east

OUTPUT=${KUBECONFIG_PATH}/nodeinfo
rm -rf ${OUTPUT}

KUBECONFIGS=($LEADER_CONFIG $WEST_CONFIG $EAST_CONFIG)
IMAMGE=nginx

function validate() {
    echo "==== start verifying ====="
    for kubeconfig in ${KUBECONFIGS[@]}; do
        kubectl --kubeconfig=${kubeconfig} run nginx --image=${IMAMGE} || true
        sleep 30
        ip=$(kubectl get pod nginx --kubeconfig=${kubeconfig} -o wide --no-headers=true | awk '{print $6}')
        echo $ip
        while IFS= read -r src; do
            node=$(echo $src | awk '{print $1}')
            echo "===== request from node $node ====="
            echo "docker exec $node bash -c curl $ip"
            docker exec $node bash -c "curl $ip"
            echo "===== successfully ====="
        done <${OUTPUT}
    done
}

for kubeconfig in ${KUBECONFIGS[@]}; do
    echo $kubeconfig
    nodenames=$(kubectl get node --kubeconfig=${kubeconfig} --no-headers=true | awk '{print $1}')
    for nodename in ${nodenames}; do
        cidr=$(kubectl get node ${nodename} --kubeconfig=${kubeconfig} -o yaml | grep "podCIDR" | grep -v "podCIDRs" | awk '{print $2}')
        ip=$(kubectl get node ${nodename} --kubeconfig=${kubeconfig} -o wide --no-headers=true | awk '{print $6}')
        echo $nodename' '${cidr}' '${ip} >>${OUTPUT}
    done
done

while IFS= read -r src; do
    node=$(echo $src | awk '{print $1}')
    while IFS= read -r dest; do
        if [[ $src = $dest ]]; then
            continue
        fi
        cidr=$(echo $dest | awk '{print $2}')
        ip=$(echo $dest | awk '{print $3}')

        echo "===== add route for node $node ====="
        echo "ip r add $cidr via $ip"
        docker exec $node bash -c "ip r add $cidr via $ip" || true
    done <${OUTPUT}
done <${OUTPUT}

validate
