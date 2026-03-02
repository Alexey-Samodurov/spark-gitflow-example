#!/usr/bin/env bash
# bootstrap.sh — одноразовая настройка кластера
# Запустить: bash scripts/bootstrap.sh
set -euo pipefail

NAMESPACE_SPARK="spark-jobs"
NAMESPACE_OPERATOR="spark-operator"
ARGOCD_NAMESPACE="argocd"
REPO_URL="${REPO_URL:-https://github.com/YOUR_ORG/spark-gitflow-example.git}"

echo "==> [1/5] Проверка kubectl и helm"
kubectl version --client --short
helm version --short

echo "==> [2/5] Установка kubeflow spark-operator"
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm repo update
helm upgrade --install spark-operator spark-operator/spark-operator \
  --namespace "${NAMESPACE_OPERATOR}" \
  --create-namespace \
  --set "spark.jobNamespaces={${NAMESPACE_SPARK}}" \
  --wait

echo "==> [3/5] Создание namespace spark-jobs"
kubectl create namespace "${NAMESPACE_SPARK}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> [4/5] Применение ArgoCD AppProject"
kubectl apply -f argocd/project.yaml

echo "==> [5/5] Регистрация репозитория в ArgoCD и применение Applications"
# Если репо приватный — добавьте: --username / --password или SSH-ключ
argocd repo add "${REPO_URL}" --insecure-skip-server-verification || true

kubectl apply -f argocd/word-count-app.yaml
kubectl apply -f argocd/data-pipeline-app.yaml

echo ""
echo "✅ Bootstrap завершён!"
echo "   ArgoCD UI: http://localhost:8080"
echo "   Namespace: ${NAMESPACE_SPARK}"
