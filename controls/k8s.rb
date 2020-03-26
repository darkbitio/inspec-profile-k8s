# Copyright 2020 Darkbit.io
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

title "Kubernetes Basics"

kversion = k8sversion()
known_registry_list = attribute('known_registry_list')

control "k8s-1" do
  impact 0.2

  title "Ensure pods only run in dedicated namespaces"

  desc "By default, user-managed resources will be placed in the `default` namespace.  This makes it difficult to properly define policies for RBAC permissions, service account usage, network policies, and more.  Creating dedicated namespaces and running workloads and supporting resources in each helps support proper API server permissions separation and network microsegmentation."
  desc "remediation", "Create dedicated namespaces for each type of related workload, and migrate those resources into those namespaces.  Ensure that RBAC permissions are not granted at the cluster scope but per namespace for the application owners at each namespace level."
  desc "validation", "Run `kubectl get all` in the `default`, `kube-public`, and if present, `kube-node-lease` namespaces.  There should only be the `kubernetes` service."

  tag platform: "K8S"
  tag category: "Workload Isolation"
  tag resource: "Pods"
  tag effort: 0.3

  ref "Kubernetes Namespaces", url: "https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/"

  describe "default namespace: pods" do
    subject { k8sobjects(api: 'v1', type: 'pods', namespace: 'default').items }
    its('length') { should cmp 0 }
  end
  describe "kube-public namespace: pods" do
    subject { k8sobjects(api: 'v1', type: 'pods', namespace: 'kube-public').items }
    its('length') { should cmp 0 }
  end
  describe "kube-node-lease namespace: pods" do
    subject { k8sobjects(api: 'v1', type: 'pods', namespace: 'kube-node-lease').items }
    its('length') { should cmp 0 }
  end
end

control "k8s-2" do
  impact 0.3

  title "Ensure the Kubernetes Dashboard is not present"

  desc "While the Kubernetes dashboard is not inherently insecure on its own, it is often coupled with a misconfiguration of RBAC permissions that can unintentionally overgrant access and is not commonly protected with `NetworkPolicies` preventing all pods from being able to reach it.  In increasingly rare circumstances, the Kubernetes dashboard is exposed publicly to the Internet."
  desc "remediation", "Instead of running a workload inside the cluster to display a UI, leverage the cloud provider's UI for listing/managing workloads or consider a tool such as Octant running on local systems.  Run `kubectl get pods --all-namespaces -l k8s-app=kubernetes-dashboard` to find pods part of deployments and use kubectl to delete those deployments."
  desc "validation", "Running `kubectl get pods --all-namespaces -l k8s-app=kubernetes-dashboard` should not return any pods."

  tag platform: "K8S"
  tag category: "Management and Governance"
  tag resource: "Pods"
  tag effort: 0.1

  ref "Kubernetes Dashboard", url: "https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/"

  describe "Dashboard: pods" do
    subject { k8sobjects(api: 'v1', type: 'pods', labelSelector: 'k8s-app=kubernetes-dashboard').items }
    its('length') { should cmp 0 }
  end
end

control "k8s-3" do
  impact 1.0

  title "Ensure Tiller (Helm v2) is not deployed"

  desc "Helm version 1.x and 2.x rely on an in-cluster deployment named `Tiller` to handle lifecycle management of Kubernetes application bundles called `charts`.  The `Tiller` deployment is commonly granted elevated privileges to be able to carry out creation/deletion of resources contained inside `charts`, and it exposes a gRPC port on TCP/44134 without authentication or authorization, by default.  This combination was common, and it afforded a simple and direct path to escalation to cluster-admin from any pod in the cluster.  Now that Helm v3 no longer relies on an in-cluster component, `Tiller` is a signal that the cluster administrators have not upgraded to the more secure version."
  desc "remediation", "Refer to https://helm.sh/docs/topics/v2_v3_migration/ for guidance on migrating away from `Tiller`.  For new cluster deployments, use Helm v3 and above going forward."
  desc "validation", "Run `kubectl get pods --all-namespaces -o name | grep tiller` and validate that no pods starting with the name `tiller-deploy-****` exist."

  tag platform: "K8S"
  tag category: "Addon Security"
  tag resource: "Pods"
  tag effort: 0.2

  ref "Helm", url: "https://helm.sh"
  ref "Tiller v2", url: "https://helm.sh/docs/faq/#removal-of-tiller"
  ref "Helm Migration from v2 to v3", url: "https://helm.sh/docs/topics/v2_v3_migration/"
  ref "Misusing Tiller", url: "https://engineering.bitnami.com/articles/helm-security.html"

  k8sobjects(api: 'v1', type: 'namespaces').items.each do |ns|
    describe "#{ns.name}/tiller-deploy: deployment" do
      subject { k8sobject(api: 'apps/v1', type: 'deployments', namespace: ns.name, name: "tiller-deploy") }
      it { should_not exist }
    end
  end
end

control "k8s-4" do
  impact 0.5

  title "Ensure all containers refer to a specific version tag not named latest"

  desc "When referring to a container image stored in a registry, it's common practice for the owner of the image to tag the most recent image with a semver tag and also the `latest` tag when uploading it.  This is a convenenience for users wanting to work with the most up-to-date image, but it presents an opportunity for inconsistencies inside Kubernetes.  If a deployment with more than one replica references an image with the tag `latest`, the underlying node will pull and run that image at that time.  If the image in the registry is updated with a new `latest` image and the deployment scales the number of replicas such that a new worker node is to run it, that node will potentially pull the newer `latest` image."
  desc "remediation", "Review all deployments and pod specifications, and modify any that reference the `latest` tag to use a specific version tag or even the `sha256` hash.  Consider enforcing this practice early with a validation step in the CI/CD pipeline and enforcing the policy with OPA/Gatekeeper or other policy-based admission controller inside the cluster."
  desc "validation", "Run `kubectl get po -A -ojsonpath='{..image}' | kubectl get pods --all-namespaces -o jsonpath='{..image}' |tr -s '[[:space:]]' '\n' | sort | uniq -c | grep latest` and ensure no images reference the `latest` tag."

  tag platform: "K8S"
  tag category: "Management and Governance"
  tag resource: "Pods"
  tag effort: 0.2

  ref "Kubectl List Images", url: "https://kubernetes.io/docs/tasks/access-application-cluster/list-all-running-container-images/"
  ref "Kubernetes Configuration Best Practices", url: "https://kubernetes.io/docs/concepts/configuration/overview/#container-images"

  k8sobjects(api: 'v1', type: 'pods').items.each do |pod|
    describe "#{pod.namespace}/#{pod.name}: pod" do
      subject { k8sobject(api: 'v1', type: 'pods', namespace: pod.namespace, name: pod.name) }
      it { should_not have_latest_container_tag }
    end
  end
end

control "k8s-5" do
  impact 0.8

  title "Ensure all pods reference container images from known sources"

  desc "By default, Kubernetes allows users with the ability to create pods to reference any container image path, including public registries like DockerHub.  This allows developers to share and use pre-made container images easily, but it enables unvalidated and untrusted code to run inside your cluster with potential access to mounted secrets and service account tokens.  Container images should be verified to be conformant to security standards before being run, and the first step to this is to validate that all container images are being pulled from a known set of registries.  This helps development teams and security teams work from the same base location for running and validating images."
  desc "remediation", "Review all deployments and pod specifications, and find any that reference non-approved container registries.  Create a dedicated container registry in your environment, validate those container images meet your security policies, and store/mirror them to that dedicated container registry/registries.  Consider enforcing image sources early with a validation step in the CI/CD pipeline and enforcing the policy with OPA/Gatekeeper or other policy-based admission controller inside the cluster."
  desc "validation", "Run `kubectl get po -A -ojsonpath='{..image}' | kubectl get pods --all-namespaces -o jsonpath='{..image}' |tr -s '[[:space:]]' '\n' | sort | uniq -c ` and ensure all images are sourced from the official Kubernetes or cloud provider registries and your own internal container registries."

  tag platform: "K8S"
  tag category: "Management and Governance"
  tag resource: "Pods"
  tag effort: 0.5

  ref "Kubectl List Images", url: "https://kubernetes.io/docs/tasks/access-application-cluster/list-all-running-container-images/"

  k8sobjects(api: 'v1', type: 'pods').items.each do |pod|
    container_images = k8sobject(api: 'v1', type: 'pods', namespace: pod.namespace, name: pod.name).container_images
    container_images.each do |ci|
      # Skip known and custom registries
      next if ci.match(Regexp.union(known_registry_list))

      describe "#{pod.namespace}/#{pod.name}[#{ci}]:" do
        it { should cmp "" }
      end
    end
  end

end

control "k8s-6" do
  impact 0.8

  title "Validate NetworkPolicy-aware enforcement is installed"

  desc "In GKE and EKS, the supported agent that can implement enforcement of `NetworkPolicy` resources is `Calico`, by Tigera.  In AKS, either `Calico` or AKS' own `azure` addon can implement micro-segmentation.  All of them are not enabled/installed by default and require explicit configuration.  In addition, the Kubernetes API will store `NetworkPolicy` resources, but without enforcement agents running, those never get applied on the nodes and pods which might cause a false sense of security."
  desc "remediation", "In GKE, enable Network Policy addon support.  In EKS, install the correct version of Calico for your version of EKS.  For AKS, configure either the `azure` or `calico` network policy addon."
  desc "validation", "Run `kubectl get daemonsets -n kube-system` and look for either `calico-node` or `azure-cni-networkmonitor` to be present."

  tag platform: "K8S"
  tag category: "Network Access Control"
  tag resource: "Daemonsets"
  tag effort: 0.5

  ref "GKE Network Policy", url: "https://cloud.google.com/kubernetes-engine/docs/how-to/network-policy#enabling_network_policy_enforcement"
  ref "EKS Network Policy", url: "https://docs.aws.amazon.com/eks/latest/userguide/calico.html"
  ref "AKS Network Policy", url: "https://docs.microsoft.com/en-us/azure/aks/use-network-policies"

  calico = k8sobjects(api: 'apps/v1', type: 'daemonsets', namespace: 'kube-system', labelSelector: 'k8s-app=calico-node').items
  azure = k8sobjects(api: 'apps/v1', type: 'daemonsets', namespace: 'kube-system', labelSelector: 'component=azure-cni-networkmonitor').items
  # One of these must be installed to pass
  describe.one do
    describe "NetworkPolicy Daemonset: installed" do
      subject { calico }
      its('count') { should be > 0 }
    end
    describe "NetworkPolicy Daemonset: installed" do
      subject { azure }
      its('count') { should be > 0 }
    end
  end
end

control "k8s-7" do
  impact 0.8

  title "Validate NetworkPolicies are defined in each namespace"

  desc "While support for `NetworkPolicies` is required in each cluster, the default policy allows all ingress and egress traffic to each pod.  Each namespace should have one or more `NetworkPolicy` resources defined to explicitly grant all ingress and egress access and to deny all other traffic.  Proper network access control at the pod level significantly reduces the ability for an attacker who has compromised a pod to move laterally to attack other pods or externally to instance metadata or cloud APIs."
  desc "remediation", "Deploy one or more `NetworkPolicy` resources in each namespace.  The most secure approach is a `default-deny-all` policy that blocks all ingress and egress traffic for that namespace followed by individual policies that allow the explicit traffic necessary."
  desc "validation", "Run `kubectl get networkpolicies --all-namespaces` and ensure each namespace has the desired policies defined."

  tag platform: "K8S"
  tag category: "Network Access Control"
  tag resource: "NetworkPolicies"
  tag effort: 0.5

  ref "Kubernetes Network Policies", url: "https://kubernetes.io/docs/concepts/services-networking/network-policies/"
  ref "Kubernetes Example Network Policies", url: "https://github.com/ahmetb/kubernetes-network-policy-recipes"

  k8sobjects(api: 'v1', type: 'namespaces').items.each do |ns|
    next if ns.name == "kube-public" || ns.name == "kube-node-lease"
    describe "#{ns.name}: one or more networkpolicies are configured" do
      subject { k8sobjects(api: 'networking.k8s.io/v1', type: 'networkpolicies', namespace: ns.name).items }
      its('count') { should be > 0 }
    end
  end
end

control "k8s-8" do
  impact 0.9

  title "Ensure resource specification enforcement is installed"

  desc "Kubernetes RBAC determines who can create/read/update/delete resources.  However, users with the RBAC permission to create pods, for example, can define a pod specification that allows for direct access to the underlying worker nodes.  This can and has led to privilege escalation by attacking other workloads after escaping their container.  Natively, the `PodSecurityPolicy` admission controller allows administrators to define policies for pod specifications to prevent them from running as root, accessing the node's filesystem, running as a `privileged` container, and more.  Effectively configured `PodSecurityPolicies` can greatly reduce the negative effects of a malicious workload, but it is limited to just resources that define `pod` specifications and `templates`.  Solutions like OPA/Gatekeeper and K-rail leverage the `ValidatingWebhookConfiguration` resource in the API server to allow external applications the ability to apply custom logic to a given request to create/update a resource and allow or deny that request.  These deployments can validate the configuration of any resource (including pod specifications) with the appropriate policies in place."
  desc "remediation", "For basic needs limited to pod specification enforcement, consider enabling the `PodSecurityPolicy` admission controller and defining policies that do not allow privileged settings.  For intermediate to advanced use cases, consider deploying OPA/Gatekeeper or K-rail inside the cluster and define policies that enforce similar constraints on `pods` as well as other resources as needed."
  desc "validation", "Run `kubectl get psps --all-namespaces` to identify `PodSecurityPolicy` resources in place, or run `kubectl get deployments --all-namespaces` and look for `gatekeeper` or `k-rail` deployments to be present."

  tag platform: "K8S"
  tag category: "Workload Isolation"
  tag resource: "Pods"
  tag effort: 0.7

  ref "OPA/Gatekeeper", url: "https://github.com/open-policy-agent/gatekeeper"
  ref "K-rail", url: "https://github.com/cruise-automation/k-rail"
  ref "Kubernetes PodSecurityPolicy": url: "https://kubernetes.io/docs/concepts/policy/pod-security-policy/"
  ref "GKE PodSecurityPolicy", url: "https://cloud.google.com/kubernetes-engine/docs/how-to/pod-security-policies"
  ref "GKE PodSecurityPolicy", url: "https://docs.aws.amazon.com/eks/latest/userguide/pod-security-policy.html"
  ref "AKS PodSecurityPolicy", url: "https://docs.microsoft.com/en-us/azure/aks/use-pod-security-policies"

  gatekeeper = k8sobjects(api: 'apps/v1', type: 'deployments', labelSelector: 'control-plane=controller-manager').items
  krail = k8sobjects(api: 'apps/v1', type: 'deployments', labelSelector: 'name=k-rail').items
  psps = k8sobjects(api: 'policy/v1beta1', type: 'podsecuritypolicies').items
  describe.one do
    describe "OPA/Gatekeeper: installed" do
      subject { gatekeeper }
      its('count') { should be > 0 }
    end
    describe "K-rail: installed" do
      subject { krail }
      its('count') { should be > 0 }
    end
    describe "PodSecurityPolicy: installed" do
      subject { psps }
      its('count') { should be > 0 }
    end
  end
end
