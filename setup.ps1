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

# Verify services and pods
kubectl get services
kubectl get pods
kubectl port-forward svc/productpage 12002:9080

# Enable mTLS enforcement for default namespace in the cluster
kubectl apply -n default -f - <<EOF
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT
EOF

# Verify your policy got deployed
kubectl get peerauthentication -n default

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

# Create job and cofigmap for scraping istio metrics with prometheus
kubectl create configmap ama-metrics-prometheus-config --from-file=prometheus-config -n kube-system

# Get Istio version Installed for importing specific dashboards
az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME  --query 'serviceMeshProfile.istio.revisions'

# Enable ACNS for the AKS cluster
az aks update --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME --enable-acns

# Setup Hubble UI
kubectl apply -f hubble-ui.yaml

kubectl -n kube-system port-forward svc/hubble-ui 12000:80