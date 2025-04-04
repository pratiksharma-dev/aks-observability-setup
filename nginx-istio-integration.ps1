# Enable mTLS for the entire service mesh
kubectl apply -n aks-istio-system -f - <<EOF
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: global-mtls
  namespace: aks-istio-system
spec:
  mtls:
    mode: STRICT
EOF

# Namespace where you want to install the ingress-nginx controller
NAMESPACE=ingress-basic
# Add nginx helm repo to your repositories
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
# Install Nginx Ingress Controller with annotation for Azure Load Balancer and externalTrafficPolicy set to Local
# This is important for the health probe to work correctly with the Azure Load Balancer
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace \
  --namespace $NAMESPACE \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
  --set controller.service.externalTrafficPolicy=Local

# Apply Ingress Resource for the sample application
kubectl apply -f ./nginx-ingress-before.yaml -n default

# Get external IP for the service
kubectl get services -n ingress-basic

# Get the istio version installed on the AKS cluster
az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME  --query 'serviceMeshProfile.istio.revisions'
# Label namespace with appropriate istio version to enable sidecar injection
kubectl label namespace <ingress-controller-namespace> istio.io/rev=asm-1-<version>
# Restart nginx ingress controller deployment so that sidecars can be injected into the pods
kubectl rollout restart deployment/ingress-nginx-controller -n ingress-basic

# Edit nginx controller deployment
kubectl edit deployments -n ingress-basic ingress-nginx-controller
# Disable all inbound port redirection to proxy (empty quotes to this property archives that)
traffic.sidecar.istio.io/includeInboundPorts: ""
# Explicitly enable inbound ports on which the cluster is exposed externally to bypass istio-proxy redirection and take traffic directly to ingress controller pods
traffic.sidecar.istio.io/excludeInboundPorts: "80,443"

# Query kubernetes API server IP
kubectl get svc kubernetes -o jsonpath='{.spec.clusterIP}'
# Add annotation to ingress controller
traffic.sidecar.istio.io/excludeOutboundIPRanges: "KUBE_API_SERVER_IP/32"

# Setup nginx to send traffic to upstream service instead of PodIP and port
nginx.ingress.kubernetes.io/service-upstream: "true" 
# Specify the service fqdn where to route the traffic (this is the service that exposes the application pods)
nginx.ingress.kubernetes.io/upstream-vhost: <service>.<namespace>.svc.cluster.local
# Apply Ingress Resource for the sample application
kubectl apply -f ./nginx-ingress-after.yaml -n default

# Apply Sidecar yaml in the namespace where ingress object is deployed    
kubectl apply -f Sidecar.yaml -n <ingress-object-namespace>


