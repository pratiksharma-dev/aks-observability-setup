# Define variables
export MY_RESOURCE_GROUP_NAME="aks-observ-rg"
export REGION="eastus2"
export MY_AKS_CLUSTER_NAME="aksobserve"


# Create a resource group
az group create --name $MY_RESOURCE_GROUP_NAME --location $REGION

# Create an AKS cluster
az aks create --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME --node-count 2 --generate-ssh-keys

# Get the credentials for the AKS cluster
az aks get-credentials --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME

# Verify the connection to your cluster 
kubectl get nodes

# Enable istio addon on AKS cluster
az aks mesh enable --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME

# Verify istiod (Istio control plane) pods are running
kubectl get pods -n aks-istio-system

# Enable sidecar injection
az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME  --query 'serviceMeshProfile.istio.revisions'
kubectl label namespace default istio.io/rev=asm-1-22

# Deploy sample application
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.18/samples/bookinfo/platform/kube/bookinfo.yaml

# Verfify services and pods
kubectl get services
kubectl get pods
kubectl port-forward svc/productpage 12002:9080

# Enable mTLS for the AKS cluster
kubectl apply -n default -f - <<EOF
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT
EOF

# Create azure monitor resource (managed prometheus resource)
export AZURE_MONITOR_NAME="aksobserveworkspace"
az resource create --resource-group $MY_RESOURCE_GROUP_NAME --namespace microsoft.monitor --resource-type accounts --name $AZURE_MONITOR_NAME --location $REGION --properties '{}'

# Create Azure Managed Grafana instance
export GRAFANA_NAME="aksobservegrafana"
az grafana create --name $GRAFANA_NAME --resource-group $MY_RESOURCE_GROUP_NAME --location $REGION

# Link Azure Monitor and Azure Managed Grafana to the AKS cluster
grafanaId=$(az grafana show --name $GRAFANA_NAME --resource-group $MY_RESOURCE_GROUP_NAME --query id --output tsv)
azuremonitorId=$(az resource show --resource-group $MY_RESOURCE_GROUP_NAME --name $AZURE_MONITOR_NAME --resource-type "Microsoft.Monitor/accounts" --query id --output tsv)
az aks update --name $MY_AKS_CLUSTER_NAME --resource-group $MY_RESOURCE_GROUP_NAME --enable-azure-monitor-metrics --azure-monitor-workspace-resource-id $azuremonitorId --grafana-resource-id $grafanaId

# Verify Azure monitor pods are running
kubectl get pods -o wide -n kube-system | grep ama-

# Enable ACNS for the AKS cluster
az aks update --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME --enable-acns

# Setup Hubble UI
kubectl apply -f hubble-ui.yaml

kubectl -n kube-system port-forward svc/hubble-ui 12000:80








kubectl create configmap ama-metrics-prometheus-config --from-file=prometheus-config -n kube-system

kubectl delete configmap ama-metrics-prometheus-config -n kube-system

kubectl get pods -n kube-system

kubectl port-forward -n kube-system svc/hubble-relay 4245:443

kubectl get pods -o wide -n kube-system -l k8s-app=hubble-relay
hubble observe --pod hubble-relay-76859646f7-2jb58
hubble observe --protocol HTTP

helm repo add kiali https://kiali.org/helm-charts

helm repo update

helm install \
    --version=1.63.1 \
    --set cr.create=true \
    --set cr.namespace=aks-istio-system \
    --namespace aks-istio-system \
    --create-namespace \
    kiali-operator \
    kiali/kiali-operator

# Generate a short-lived token to login to Kiali UI
kubectl -n aks-istio-system create token kiali-service-account

# Port forward to Istio service to access on http://localhost:20001
kubectl port-forward svc/kiali 20001:20001 -n aks-istio-system

kubectl run -it --rm aks-ssh --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11

kubectl exec --stdin --tty details-v1-6c98bc7c4c-5xsmx -- /bin/bash

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu
  labels:
    app: ubuntu
spec:
  containers:
  - image: ubuntu
    command:
      - "sleep"
      - "604800"
    imagePullPolicy: IfNotPresent
    name: ubuntu
  restartPolicy: Always
EOF

kubectl exec -it ubuntu -- /bin/bash

apt-get -y update; apt-get -y install curl

curl http://10.244.1.106:9080 | grep -o "<title>.*</title>"