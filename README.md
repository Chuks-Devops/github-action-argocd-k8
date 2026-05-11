# DevOps CI/CD Platform with GitHub Actions, ArgoCD, AWS & Kubernetes

A production-ready DevOps workflow using:

* GitHub Actions for CI/CD
* Docker for containerization
* AWS for cloud infrastructure
* Kubernetes (EKS or self-managed)
* ArgoCD for GitOps deployment
* NGINX Ingress Controller
* Terraform (optional infrastructure provisioning)

---

# Architecture Overview

```text
Developer Pushes Code
        │
        ▼
 GitHub Actions CI
 ├── Run Tests
 ├── Build Docker Image
 ├── Push to Docker Registry
 └── Update Kubernetes Manifest
        │
        ▼
 Git Repository (GitOps Repo)
        │
        ▼
      ArgoCD
        │
        ▼
 Kubernetes Cluster (AWS EKS)
        │
        ▼
   Application Running
```

---

# Tech Stack

| Tool           | Purpose                             |
| -------------- | ----------------------------------- |
| GitHub Actions | Continuous Integration / Deployment |
| Docker         | Application containerization        |
| Kubernetes     | Container orchestration             |
| AWS EKS        | Managed Kubernetes                  |
| ArgoCD         | GitOps continuous delivery          |
| NGINX Ingress  | Routing external traffic            |
| Terraform      | Infrastructure as Code              |

---

# Project Structure

```bash
.
├── .github/
│   └── workflows/
│       └── ci.yml
├── kubernetes/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
├── argocd/
│   └── application.yaml
├── Dockerfile
```

---

# Prerequisites

Before starting, install:

* Docker
* kubectl
* AWS CLI
* Terraform
* ArgoCD CLI
* eksctl

Useful links:

* GitHub Actions Documentation: [https://docs.github.com/actions](https://docs.github.com/actions)
* ArgoCD Documentation: [https://argo-cd.readthedocs.io](https://argo-cd.readthedocs.io)
* AWS EKS Documentation: [https://docs.aws.amazon.com/eks](https://docs.aws.amazon.com/eks)
* Kubernetes Documentation: [https://kubernetes.io/docs/home/](https://kubernetes.io/docs/home/)

---

# Step 1 — Build Docker Image

## Dockerfile

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
```

Build locally:

```bash
docker build -t myapp .
```

---



Authenticate Docker:

```bash
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS \
--password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
```

Tag image:

```bash
docker tag myapp:latest \
<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/myapp:latest
```

Push image:

```bash
docker push \
image-name:latest
```

---

# Step 3 — Create AWS EKS Cluster

Using eksctl:

```bash
eksctl create cluster \
  --name devops-cluster \
  --region us-east-1 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 2
```

Verify cluster:

```bash
kubectl get nodes
```

---

# Step 4 — Kubernetes Deployment

## deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp

  template:
    metadata:
      labels:
        app: myapp

    spec:
      containers:
        - name: myapp
          image: image-name:latest

          ports:
            - containerPort: 3000
```

---

## service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service

spec:
  selector:
    app: myapp

  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000

  type: ClusterIP
```

---

## ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress

metadata:
  name: myapp-ingress
  annotations:
    kubernetes.io/ingress.class: nginx

spec:
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix

            backend:
              service:
                name: myapp-service
                port:
                  number: 80
```

Apply resources:

```bash
kubectl apply -f kubernetes/
```

---

# Step 5 — Install ArgoCD

Create namespace:

```bash
kubectl create namespace argocd
```

Install ArgoCD:

```bash
kubectl apply -n argocd \
-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Access UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open:

```text
https://localhost:8080
```

Get admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
-o jsonpath="{.data.password}" | base64 -d
```

---

# Step 6 — Create ArgoCD Application

## application.yaml

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: myapp

spec:
  project: default

  source:
    repoURL: https://github.com/yourusername/devops-project.git
    targetRevision: HEAD
    path: kubernetes

  destination:
    server: https://kubernetes.default.svc
    namespace: default

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Apply:

```bash
kubectl apply -f argocd/application.yaml
```

---

# Step 7 — GitHub Actions CI/CD

## .github/workflows/ci.yml

```yaml
name: CI/CD Pipeline

on:
  push:
    branches:
      - main

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: myapp

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build Docker Image
        run: |
          docker build -t $ECR_REPOSITORY .

      - name: Tag Docker Image
        run: |
          docker tag $ECR_REPOSITORY:latest \
          ${{ steps.login-ecr.outputs.registry }}/$ECR_REPOSITORY:${{ github.sha }}

      - name: Push Docker Image
        run: |
          docker push \
          ${{ steps.login-ecr.outputs.registry }}/$ECR_REPOSITORY:${{ github.sha }}
```

---

# GitHub Secrets

Add these in GitHub repository settings:

| Secret                | Description    |
| --------------------- | -------------- |
| AWS_ACCESS_KEY_ID     | AWS access key |
| AWS_SECRET_ACCESS_KEY | AWS secret key |

---

# Step 8 — Enable GitOps Flow

Best practice:

1. CI pipeline builds image
2. CI updates Kubernetes manifest image tag
3. GitHub Actions commits updated manifest
4. ArgoCD detects change
5. ArgoCD syncs deployment automatically

---

# Install NGINX Ingress Controller

```bash
kubectl apply -f \
https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

Verify:

```bash
kubectl get svc -n ingress-nginx
```

---

# Security Best Practices

* Use Base Image
* Store sensitive information on secrets
* Use HTTPS with TLS certificates
---

# Useful Commands

## Kubernetes

```bash
kubectl get pods
kubectl get svc
kubectl logs <pod-name>
kubectl describe pod <pod-name>
```

## ArgoCD

```bash
argocd app list
argocd app sync myapp
```

---

# CI/CD Flow Summary

```text
GitHub Push
    ↓
GitHub Actions
    ↓
Docker Build
    ↓
Docker Hub
    ↓
Manifest Update
    ↓
ArgoCD Detects Change
    ↓
Kubernetes Deployment
```

---

# Future Improvements

* Helm Charts
* Multi-Environment Deployments
* Service Mesh (Istio)
* Automated Rollbacks
* GitOps promotion workflow

---

# Author

Built for scalable cloud-native deployments using:

* GitHub
* Amazon Web Services (AWS)
* Argo CD
* Kubernetes
