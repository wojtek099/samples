ENVS := stage prod
REGIONS := eu-west-1 us-east-1 us-west-2 eu-central-1 ap-northeast-1
env := stage
region := eu-west-1
APP := data-jobs
TF := terraform13
# BRANCH := $(shell git rev-parse --abbrev-ref HEAD |sed -e 's/\//_/')
account := $(shell aws sts get-caller-identity |jq -r .Account)
account_prod := <redacted>
account_stage := <redacted>

test:
	@echo "test $(account_$(env))"
ifneq ($(account_$(env)),$(account))
	$(error account $(account) env $(env) account mismatch)
endif
.PHONY: dynamodb
dynamodb:
	aws --region eu-west-1 dynamodb create-table \
    --table-name $(APP)-terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
help:
	@echo "account $(account)"
tf_init:
ifeq ($(filter $(env),$(ENVS)),)
	$(error $(env) is not supported)
endif
ifeq ($(filter $(region),$(REGIONS)),)
	$(error $(region) is not supported)
endif
ifneq ($(account_$(env)),$(account))
	$(error account $(account) env $(env) account mismatch)
endif
	@if [ -e .terraform/terraform.tfstate ]; then rm .terraform/terraform.tfstate; fi;
	$(TF) init -backend-config="bucket=terraform-jp-$(env)" -backend-config="dynamodb_table=$(APP)-terraform-state-lock" -backend-config="key=$(APP)-terraform-$(region).tfstate"
tf_vars:
	$(eval TF_OPTIONS :=  $(TF_OPTIONS) -var-file=.$(env).$(region).env -var region=$(region) -var app=$(APP))
ifneq ($(target),)
	$(eval TF_OPTIONS :=  $(TF_OPTIONS) -target=$(target))
  	# $(error ENV is not set)
endif
	@echo "# TF_OPTIONS= "$(TF_OPTIONS)

.PHONY: plan 
plan: tf_init tf_vars
	$(TF) plan $(TF_OPTIONS)

.PHONY: apply
apply: tf_init tf_vars
	$(TF) apply $(TF_OPTIONS)

.PHONY: destroy 
destroy: tf_init tf_vars
	$(TF) destroy $(TF_OPTIONS)

.PHONY: autoapply
autoapply: tf_init tf_vars
	$(TF) apply -auto-approve $(TF_OPTIONS)

.PHONY: output
output: tf_init tf_vars
	$(TF) output $(TF_OPTIONS)

.PHONY: import
import: tf_init tf_vars
	$(TF) import $(TF_OPTIONS) $(val)

