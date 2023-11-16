# Copyright Wojciech Kaczmarczyk
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# Bootstrap eks cluster

echo 'CLUSTER_NAME:'
echo $CLUSTER_NAME
echo ''
echo 'AWS_REGION:'
echo $AWS_REGION
echo ''

eksctl create cluster -f eks.yaml

aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}

eksctl utils associate-iam-oidc-provider --region=${AWS_REGION} --cluster=${CLUSTER_NAME} --approve

eksctl create iamserviceaccount \
  --region ${AWS_REGION} \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster ${CLUSTER_NAME} \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --role-only \
  --role-name AmazonEKS_EBS_CSI_DriverRole

eksctl create addon --name aws-ebs-csi-driver --cluster ${CLUSTER_NAME} --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AmazonEKS_EBS_CSI_DriverRole --force

# Provision Istio

istioctl install --set profile=demo -y 

# Istio-injection enable for default namespace

kubectl label namespace default istio-injection=enabled

# Deploy Bookinfo app
echo 'Deploy Bookinfo app'

kubectl apply -f ../bookinfo.yaml

echo 'Sleep waiting for pods and services readiness'
sleep 120
# Verify
echo 'services:'
kubectl get services

echo 'pods:'
kubectl get pods

echo 'check propductpage endpoint from pod'
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" -c ratings -- curl -sS productpage:9080/productpage | grep -o "<title>.*</title>"

# Open the application to outside traffic

kubectl apply -f ../bookinfo-gateway.yaml
echo 'Sleep waiting for Bookinfo gateway pods and services readiness'
sleep 120

istioctl analyze

# provide ingress local variables for local console

export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')

echo "export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')"
echo "export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')"
echo "paste above if you want to use other terminal window"

echo 'INGRESS_HOST: ' $INGRESS_HOST
echo 'INGRESS_PORT: ' $INGRESS_PORT
echo 'SECURE_INGRESS_PORT:' $SECURE_INGRESS_PORT

# provide gateway url 

export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo 'GATEWAY_URL: ' $GATEWAY_URL

# Verify external access

echo "http://$GATEWAY_URL/productpage"
PRODUCT_PAGE_ENDPOINT="http://$GATEWAY_URL/productpage"
curl $PRODUCT_PAGE_ENDPOINT
echo '============================================'
echo 'Done!'
echo "http://$GATEWAY_URL/productpage"
echo "please check above url in visual browser"
echo '============================================'

# Install telemetry addons

kubectl apply -f ../samples/addons
echo 'Sleep waiting for Bookinfo gateway pods and services readiness'
sleep 120
kubectl rollout status deployment/kiali -n istio-system
kubectl get all -n istio-system

# Simulate trafic to application endpoint

bash ../tests/load.sh

# open Kiali dashboard
echo 'go to below url, if not opened'
istioctl dashboard kiali
