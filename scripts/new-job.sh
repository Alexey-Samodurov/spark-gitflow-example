#!/usr/bin/env bash
# new-job.sh — scaffold нового Spark джоба
# Использование: bash scripts/new-job.sh my-new-job
set -euo pipefail

JOB_NAME="${1:?Укажите имя джоба: bash scripts/new-job.sh <job-name>}"
DEST="jobs/${JOB_NAME}"

if [[ -d "${DEST}" ]]; then
  echo "❌ Директория ${DEST} уже существует"
  exit 1
fi

mkdir -p "${DEST}"

cat > "${DEST}/Chart.yaml" <<EOF
apiVersion: v2
name: ${JOB_NAME}
description: Spark job — ${JOB_NAME}
type: application
version: 0.1.0
appVersion: "1.0.0"
dependencies:
  - name: spark-job
    version: "0.1.0"
    repository: "file://../../charts/spark-job"
    alias: sparkJob
EOF

cat > "${DEST}/values.yaml" <<EOF
sparkJob:
  image:
    repository: my-registry/${JOB_NAME}
    tag: "latest"
    pullPolicy: IfNotPresent

  job:
    type: Python                       # Scala | Python | Java | R
    sparkVersion: "3.5.0"
    mainApplicationFile: "local:///app/main.py"
    arguments: []

  driver:
    cores: 1
    coreLimit: "1200m"
    memory: "1g"

  executor:
    instances: 2
    cores: 1
    memory: "1g"

  sparkConf:
    spark.sql.adaptive.enabled: "true"

  restartPolicy:
    type: OnFailure
    onFailureRetries: 3
    onFailureRetryInterval: 10
    onSubmissionFailureRetries: 5
    onSubmissionFailureRetryInterval: 20

  serviceAccount:
    create: true
EOF

cat > "argocd/${JOB_NAME}-app.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: spark-${JOB_NAME}
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: spark-gitflow
    spark-job: ${JOB_NAME}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: spark-jobs
  source:
    repoURL: https://github.com/YOUR_ORG/spark-gitflow-example.git
    targetRevision: master
    path: jobs/${JOB_NAME}
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: spark-jobs
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 3
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 3m
EOF

echo "✅ Джоб создан: ${DEST}"
echo "   ArgoCD манифест: argocd/${JOB_NAME}-app.yaml"
echo ""
echo "Следующие шаги:"
echo "  1. Отредактируйте ${DEST}/values.yaml"
echo "  2. Запустите: make deps JOB=${JOB_NAME}"
echo "  3. Закоммитьте и запушьте в master — ArgoCD синхронизирует автоматически"
