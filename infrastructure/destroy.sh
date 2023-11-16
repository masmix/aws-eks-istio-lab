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

# Delete addons components

kubectl delete -f ../samples/addons

# Delete Bookinfo gateway components

kubectl delete -f ../samples/bookinfo/networking/bookinfo-gateway.yaml

# Delete Book

kubectl delete -f ../samples/bookinfo/platform/kube/bookinfo.yaml

# 
eksctl delete cluster -f eks.yaml