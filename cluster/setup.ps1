# Set the working directory to the script's location
Set-Location -Path $PSScriptRoot

# Stop script execution on error
$ErrorActionPreference = "Stop"

# Define namespaces
$PrometheusNamespace = "monitoring"
$MetallbNamespace = "metallb-system"
$ApisixNamespace = "apisix"
$KafkaNamespace = "kafka"

# Define Kind cluster config file with labeled nodes
kind create cluster --config=./manifests/kind-config.yaml

# Wait for nodes to be ready
Write-Output "Waiting for nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Label nodes for scheduling
Write-Output "Labeling nodes..."
kubectl label node c1-control-plane ingress-enabled=true --overwrite
kubectl label node c1-worker prometheus-node=true --overwrite

Write-Output "Nodes have been labeled:"
kubectl get nodes --show-labels

# Update Helm repositories
Write-Output "Updating Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add metallb https://metallb.github.io/metallb
helm repo add apisix https://charts.apiseven.com
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update


# Install MetalLB using values file
Write-Output "Installing MetalLB..."
helm install metallb metallb/metallb --create-namespace --namespace $MetallbNamespace --values values/metallb-values.yaml --wait 

kubectl apply -f ./manifests/metallb-config.yaml

# Install Prometheus using values file
Write-Output "Installing Prometheus..."
helm install prometheus-stack prometheus-community/kube-prometheus-stack --create-namespace --namespace $PrometheusNamespace --values values/prometheus-values.yaml --wait

# Install APISIX using values file
Write-Output "Installing APISIX..."
helm upgrade --install apisix apisix/apisix --create-namespace --namespace $ApisixNamespace --values values/apisix-values.yaml --wait

# Install Kafka using values file
Write-Output "Installing Kafka..."
helm install kafka bitnami/kafka --create-namespace --namespace $KafkaNamespace --values values/kafka-values.yaml --wait

#Deploy Postgress
kubectl apply -f ./manifests/postgres.yaml
