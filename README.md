# Spark GitFlow Example

Репозиторий для запуска Apache Spark джобов через **kubeflow/spark-operator** + **Helm** + **ArgoCD**.

## Архитектура

```
master branch
     │
     ▼
ArgoCD Application (per job)
     │  source: jobs/<job-name>/  (Helm chart)
     │  targetRevision: master
     ▼
SparkApplication CRD (spark-operator)
     │
     ▼
Kubernetes namespace: spark-jobs
```

## Быстрый старт

### 1. Предварительные требования

```bash
# Проверить, что всё установлено
kubectl version --client
helm version
argocd version --client
```

- Kubernetes (дефолтный контекст)
- ArgoCD задеплоен в namespace `argocd`
- kubeflow/spark-operator **или** устанавливается через bootstrap

## Запустить скрипт bootstrap.sh
```bash
scripts/bootstrap.sh
```

## Параметры values.yaml

Все доступные параметры базового чарта: [`charts/spark-job/values.yaml`](charts/spark-job/values.yaml)

Ключевые:

| Параметр | Описание |
|---|---|
| `sparkJob.image.repository` | Docker образ Spark приложения |
| `sparkJob.image.tag` | Тег образа |
| `sparkJob.job.type` | `Scala` / `Python` / `Java` / `R` |
| `sparkJob.job.mainClass` | Главный класс (для JVM) |
| `sparkJob.job.mainApplicationFile` | Путь к jar/py файлу |
| `sparkJob.driver.cores` / `memory` | Ресурсы драйвера |
| `sparkJob.executor.instances` / `cores` / `memory` | Ресурсы и кол-во экзекьюторов |
| `sparkJob.sparkConf` | Произвольные `spark.*` конфиги (map) |
| `sparkJob.restartPolicy.type` | `Never` / `OnFailure` / `Always` |
