#!/bin/bash

set -e  # Exit on error
set -u  # Treat unset variables as errors
set -o pipefail  # Fail if any command in a pipeline fails

# Define namespaces
PROMETHEUS_NAMESPACE="monitoring"
METALLB_NAMESPACE="metallb-system"
APISIX_NAMESPACE="apisix"
KAFKA_NAMESPACE="kafka"

# Create Kind cluster from config file
echo "Creating Kind cluster..."
kind create cluster --config=kind-config.yaml

# Wait for nodes to be ready
echo "Waiting for nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Label nodes for scheduling
echo "Labeling nodes..."
kubectl label node kind-control-plane control-plane=true --overwrite
kubectl label node kind-worker app=prometheus --overwrite
kubectl label node kind-worker2 app=metallb --overwrite
kubectl label node kind-worker3 app=apisix --overwrite
kubectl label node kind-worker4 app=kafka --overwrite

echo "Nodes have been labeled:"
kubectl get nodes --show-labels

# Update Helm repositories
echo "Updating Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add metallb https://metallb.github.io/metallb
helm repo add apisix https://charts.apiseven.com
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install Prometheus using values file
echo "Installing Prometheus..."
kubectl create namespace $PROMETHEUS_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
helm install prometheus prometheus-community/prometheus --namespace $PROMETHEUS_NAMESPACE \
  --values values/prometheus-values.yaml --wait

# Install MetalLB using values file
echo "Installing MetalLB..."
kubectl create namespace $METALLB_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
helm install metallb metallb/metallb --namespace $METALLB_NAMESPACE \
  --values values/metallb-values.yaml --wait

# Apply MetalLB IP Address Pool and L2 Advertisement (CRDs)
echo "Configuring MetalLB IP Pools..."
kubectl apply -f metallb-config.yaml

# Install APISIX using values file
echo "Installing APISIX..."
kubectl create namespace $APISIX_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
helm install apisix apisix/apisix --namespace $APISIX_NAMESPACE \
  --values values/apisix-values.yaml --wait

# Install Kafka using values file
echo "Installing Kafka..."
kubectl create namespace $KAFKA_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
helm install kafka bitnami/kafka --namespace $KAFKA_NAMESPACE \
  --values values/kafka-values.yaml --wait

Write-Output "All services have been deployed succesfully"