# Spark GitFlow Example

Репозиторий для запуска Apache Spark джобов через **kubeflow/spark-operator** + **Helm** + **ArgoCD**, одна ветка `master`.

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

### Структура репозитория

```
├── charts/
│   └── spark-job/          # Базовый (library) Helm chart с шаблоном SparkApplication CRD
│       ├── Chart.yaml
│       ├── values.yaml     # Все параметры с дефолтами + JSON schema валидация
│       └── templates/
│           ├── sparkapplication.yaml
│           ├── serviceaccount.yaml
│           └── rbac.yaml
│
├── jobs/                   # Каждая папка = один Spark джоб
│   ├── word-count/         # Helm umbrella chart (зависит от charts/spark-job)
│   │   ├── Chart.yaml
│   │   └── values.yaml     # Параметры конкретного джоба
│   └── data-pipeline/
│       ├── Chart.yaml
│       └── values.yaml
│
├── argocd/
│   ├── project.yaml            # ArgoCD AppProject (RBAC, whitelist ресурсов)
│   ├── word-count-app.yaml     # ArgoCD Application → jobs/word-count
│   └── data-pipeline-app.yaml  # ArgoCD Application → jobs/data-pipeline
│
├── scripts/
│   ├── bootstrap.sh        # Установка spark-operator + регистрация Apps в ArgoCD
│   └── new-job.sh          # Scaffolding нового джоба
│
└── Makefile                # Удобные цели: lint, sync, logs, new-job, ...
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

### 2. Bootstrap

```bash
# Установить spark-operator, создать namespace, подключить ArgoCD
REPO_URL=https://github.com/YOUR_ORG/spark-gitflow-example.git make bootstrap
```

Скрипт выполнит:
1. `helm install spark-operator` в namespace `spark-operator`
2. `kubectl create namespace spark-jobs`
3. `kubectl apply -f argocd/project.yaml`
4. `kubectl apply -f argocd/*-app.yaml`

### 3. Обновление джоба

```bash
# Редактируем jobs/word-count/values.yaml
vim jobs/word-count/values.yaml

# Коммитим и пушим в master
git add jobs/word-count/values.yaml
git commit -m "feat(word-count): increase executor instances to 4"
git push origin master

# ArgoCD синхронизирует автоматически (automated.selfHeal=true)
# Или принудительно:
make sync JOB=word-count
```

### 4. Добавить новый джоб

```bash
make new-job JOB=my-etl-job
# Редактируем jobs/my-etl-job/values.yaml
vim jobs/my-etl-job/values.yaml
make deps JOB=my-etl-job
make lint
git add . && git commit -m "feat: add my-etl-job" && git push origin master
make apply JOB=my-etl-job   # регистрируем Application в ArgoCD
```

## Makefile команды

```bash
make help          # Полный список команд
make bootstrap     # Одноразовая настройка кластера
make lint          # Helm lint всех чартов
make template JOB=word-count   # Рендер шаблонов (dry-run)
make diff JOB=word-count       # ArgoCD diff
make sync JOB=word-count       # Принудительный sync
make sync-all                  # Sync всех джобов
make status                    # Статус всех Application
make logs JOB=word-count       # Логи driver пода
make spark-apps                # kubectl get sparkapplication
make port-forward              # ArgoCD UI на localhost:8080
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
