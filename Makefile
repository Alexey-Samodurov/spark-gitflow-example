.DEFAULT_GOAL := help
SHELL         := /bin/bash

ARGOCD_NS     ?= argocd
SPARK_NS      ?= spark-jobs
REPO_URL      ?= https://github.com/YOUR_ORG/spark-gitflow-example.git
JOB           ?= word-count   # переопределяется через: make <target> JOB=my-job

# ─────────────────────────────────────────────────────────────
# Bootstrap
# ─────────────────────────────────────────────────────────────
.PHONY: bootstrap
bootstrap: ## Установить spark-operator, создать namespace, зарегистрировать ArgoCD Applications
	REPO_URL=$(REPO_URL) bash scripts/bootstrap.sh

# ─────────────────────────────────────────────────────────────
# Управление джобами
# ─────────────────────────────────────────────────────────────
.PHONY: new-job
new-job: ## Создать scaffolding нового джоба: make new-job JOB=my-job
	bash scripts/new-job.sh $(JOB)

.PHONY: deps
deps: ## helm dependency update для джоба: make deps JOB=word-count
	helm dependency update jobs/$(JOB)

.PHONY: deps-all
deps-all: ## helm dependency update для всех джобов
	@for job in jobs/*/; do \
		echo "→ $$job"; \
		helm dependency update "$$job"; \
	done

# ─────────────────────────────────────────────────────────────
# Lint / Validate
# ─────────────────────────────────────────────────────────────
.PHONY: lint
lint: ## Lint всех Helm чартов
	helm lint charts/spark-job
	@for job in jobs/*/; do \
		echo "→ lint $$job"; \
		helm lint "$$job"; \
	done

.PHONY: template
template: ## Рендер шаблонов для джоба: make template JOB=word-count
	helm dependency update jobs/$(JOB) --quiet
	helm template spark-$(JOB) jobs/$(JOB) --namespace $(SPARK_NS)

.PHONY: diff
diff: ## ArgoCD diff для джоба: make diff JOB=word-count
	argocd app diff spark-$(JOB)

# ─────────────────────────────────────────────────────────────
# ArgoCD операции
# ─────────────────────────────────────────────────────────────
.PHONY: apply
apply: ## Применить ArgoCD Application для джоба: make apply JOB=word-count
	kubectl apply -f argocd/$(JOB)-app.yaml

.PHONY: apply-all
apply-all: ## Применить все ArgoCD Applications
	kubectl apply -f argocd/project.yaml
	@for f in argocd/*-app.yaml; do \
		echo "→ apply $$f"; \
		kubectl apply -f "$$f"; \
	done

.PHONY: sync
sync: ## Принудительный sync джоба в ArgoCD: make sync JOB=word-count
	argocd app sync spark-$(JOB)

.PHONY: sync-all
sync-all: ## Sync всех spark-* Applications в ArgoCD
	@argocd app list -o name | grep '^spark-' | xargs -I{} argocd app sync {}

.PHONY: status
status: ## Статус всех spark-* Applications
	argocd app list -l app.kubernetes.io/part-of=spark-gitflow

.PHONY: delete
delete: ## Удалить ArgoCD Application (джоб): make delete JOB=word-count
	argocd app delete spark-$(JOB) --cascade

# ─────────────────────────────────────────────────────────────
# Утилиты
# ─────────────────────────────────────────────────────────────
.PHONY: port-forward
port-forward: ## Пробросить порт ArgoCD UI на localhost:8080
	kubectl port-forward svc/argocd-server -n $(ARGOCD_NS) 8080:443

.PHONY: logs
logs: ## Логи драйвера последнего SparkApplication: make logs JOB=word-count
	kubectl logs -n $(SPARK_NS) \
		$$(kubectl get pod -n $(SPARK_NS) -l spark-role=driver,app.kubernetes.io/instance=spark-$(JOB) \
		   -o jsonpath='{.items[-1].metadata.name}') --follow

.PHONY: spark-apps
spark-apps: ## Список SparkApplications в namespace
	kubectl get sparkapplication -n $(SPARK_NS)

.PHONY: help
help: ## Показать справку
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
