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

control "k8s-1" do
  impact 1.0
  title "Ensure pods only run in desired namespaces"
  desc "description"
  desc "remediation", "remediation"

  tag domain: "01. Identity and Access Management"
  tag platform: "K8S"
  tag category: "Identity and Access Management"
  tag resource: "Pods"
  tag effort: 0.2

  ref "ref1", url: "https://ref1.local"

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
  impact 1.0
  title "Ensure Dashboard is not running"
  desc "Ensure Dashboard is not running"
  desc "remediation", "remediation"

  tag domain: "01. Identity and Access Management"
  tag platform: "K8S"
  tag category: "Identity and Access Management"
  tag resource: "Pods"
  tag effort: 0.2

  ref "ref1", url: "https://ref1.local"

  describe "Dashboard: pods" do
    subject { k8sobjects(api: 'v1', type: 'pods', labelSelector: 'k8s-app=kubernetes-dashboard').items }
    its('length') { should cmp 0 }
  end
end

control "k8s-3" do
  impact 1.0
  title "Ensure Tiller is not running"
  desc "Ensure Tiller is not running"
  desc "remediation", "remediation"

  tag domain: "01. Identity and Access Management"
  tag platform: "K8S"
  tag category: "Identity and Access Management"
  tag resource: "Pods"
  tag effort: 0.2

  ref "ref1", url: "https://ref1.local"

  k8sobjects(api: 'v1', type: 'namespaces').items.each do |ns|
    describe "#{ns.name}/tiller-deploy: deployment" do
      subject { k8sobject(api: 'extensions/v1beta1', type: 'deployments', namespace: ns.name, name: "tiller-deploy") }
      it { should_not exist }
    end
  end
end

control "k8s-4" do
  impact 1.0
  title "No pods with latest container tag"
  desc ""
  desc "remediation", "remediation"

  tag domain: "01. Identity and Access Management"
  tag platform: "K8S"
  tag category: "Identity and Access Management"
  tag resource: "Pods"
  tag effort: 0.2

  ref "ref1", url: "https://ref1.local"

  k8sobjects(api: 'v1', type: 'pods').items.each do |pod|
    describe "#{pod.namespace}/#{pod.name}: pod" do
      subject { k8sobject(api: 'v1', type: 'pods', namespace: pod.namespace, name: pod.name) }
      it { should_not have_latest_container_tag }
    end
  end
end

control "k8s-5" do
  impact 1.0
  title "Validate NetworkPolicy enforcement is installed"
  desc "Ensure Calico is installed on EKS/GKE or Azure CNI is installed on AKS"
  desc "remediation", "remediation"

  tag domain: "01. Identity and Access Management"
  tag platform: "K8S"
  tag category: "Identity and Access Management"
  tag resource: "Pods"
  tag effort: 0.2

  ref "ref1", url: "https://ref1.local"

  calico = k8sobjects(api: 'apps/v1', type: 'daemonsets', namespace: 'kube-system', labelSelector: 'k8s-app=calico-node').items
  azure = k8sobjects(api: 'apps/v1', type: 'daemonsets', namespace: 'kube-system', labelSelector: 'component=azure-cni-networkmonitor').items
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

control "k8s-6" do
  impact 1.0
  title "Validate PodSpec enforcement is installed"
  desc "Ensure OPA/Gatekeeper, K-rail, or PSP is installed"
  desc "remediation", "remediation"

  tag domain: "01. Identity and Access Management"
  tag platform: "K8S"
  tag category: "Identity and Access Management"
  tag resource: "Pods"
  tag effort: 0.2

  ref "ref1", url: "https://ref1.local"

  gatekeeper = k8sobjects(api: 'extensions/v1beta1', type: 'deployments', labelSelector: 'control-plane=controller-manager').items
  krail = k8sobjects(api: 'extensions/v1beta1', type: 'deployments', labelSelector: 'name=k-rail').items
  describe.one do
    describe "OPA/Gatekeeper: installed" do
      subject { gatekeeper }
      its('count') { should be > 0 }
    end
    describe "K-rail: installed" do
      subject { krail }
      its('count') { should be > 0 }
    end
  end
end

#control "k8s-100" do
#  impact 1.0
#  title "Validate ResourceQuotas"
#  desc ""
#  desc "remediation", "remediation"
#
#  tag domain: "01. Identity and Access Management"
#  tag platform: "K8S"
#  tag category: "Identity and Access Management"
#  tag resource: "Pods"
#  tag effort: 0.2
#
#  ref "ref1", url: "https://ref1.local"
#
#  k8sobjects(api: 'v1', type: 'namespaces').items.each do |ns|
#    next if ns.name == "kube-node-lease" || ns.name == "kube-public"
#    describe "#{ns.name}: namespace resourcequotas" do
#      subject { k8sobjects(api: 'v1', type: 'resourcequotas', namespace: ns.name).items }
#      its('count') { should be > 0 }
#    end
#    k8sobjects(api: 'v1', type: 'resourcequotas', namespace: ns.name).items.each do |rq|
#      describe "#{rq.namespace}/#{rq.name} resourcequota" do
#        subject { k8sobject(api: 'v1', type: 'resourcequotas', namespace: rq.namespace, name: rq.name) }
#        it { should exist }
#      end
#    end
#  end
#end
#
#control "k8s-101" do
#  impact 1.0
#  title "Validate LimitRange"
#  desc ""
#  desc "remediation", "remediation"
#
#  tag domain: "01. Identity and Access Management"
#  tag platform: "K8S"
#  tag category: "Identity and Access Management"
#  tag resource: "Pods"
#  tag effort: 0.2
#
#  ref "ref1", url: "https://ref1.local"
#
#  k8sobjects(api: 'v1', type: 'namespaces').items.each do |ns|
#    next if ns.name == "kube-node-lease" || ns.name == "kube-public"
#    describe "#{ns.name}: namespace limitranges" do
#      subject { k8sobjects(api: 'v1', type: 'limitranges', namespace: ns.name).items }
#      its('count') { should be > 0 }
#    end
#    k8sobjects(api: 'v1', type: 'limitranges', namespace: ns.name).items.each do |lr|
#      describe "#{lr.namespace}/#{lr.name} limitranges" do
#        subject { k8sobject(api: 'v1', type: 'limitranges', namespace: lr.namespace, name: lr.name) }
#        it { should exist }
#      end
#    end
#  end
#end
