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

SHELL := /usr/bin/env bash

IMAGENAME=mkit
IMAGEREPO=darkbitio/$(IMAGENAME)
WORKDIR=/share

DOCKERBUILD=docker build -t $(IMAGEREPO):latest .
COMMAND=docker run --rm -it -v `pwd`:$(WORKDIR) -v $(HOME)/.kube:/root/.kube:ro 
IMAGEPATH=$(IMAGEREPO):latest
INSPECRUN=$(COMMAND) $(IMAGEPATH) exec . -t k8s:// | ./lib/inspec-results-to-findings.rb
DEBUGSHELL=$(COMMAND) --entrypoint /bin/bash $(IMAGEPATH)

build:
	@echo "Building $(IMAGEREPO):latest"
	@$(DOCKERBUILD)
run:
	@echo "Running in $(IMAGEREPO):latest: inspec exec . -t k8s://"
	@$(INSPECRUN)
shell:
	@echo "Running a shell inside the container"
	@$(DEBUGSHELL)

.PHONY: build run shell
