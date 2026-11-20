# Guía y Documentación de Punta a Punta: Despliegue OIDC, Bootstrap y Pipeline CI/CD Serverless

Este documento describe detalladamente la arquitectura, diagnóstico de problemas, correcciones técnicas, despliegue del Bootstrap y la ejecución completa del pipeline de Integración y Entrega Continua (CI/CD) para el proyecto **Citas Escolares Serverless**.

---

## 1. Resumen Ejecutivo y Contexto del Problema

### El Problema
Al intentar ejecutar el flujo de despliegue mediante GitHub Actions, la autenticación contra Amazon Web Services (AWS) mediante el servicio de tokens de seguridad (STS) fallaba con el siguiente error:
```text
An error occurred (AccessDenied) when calling the AssumeRoleWithWebIdentity operation: 
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

### Causa Raíz
A partir de julio de 2026, GitHub implementó una actualización de seguridad en su proveedor OpenID Connect (OIDC) conocida como **Immutable Subject Claims (`sub`)**. 
* **Comportamiento Clásico (Legacy):** El claim `sub` del token JWT tenía la estructura basada únicamente en nombres de usuario y repositorio:
  ```text
  repo:<usuario_o_organizacion>/<nombre_repo>:ref:refs/heads/<rama>
  ```
* **Comportamiento Actual (Inmutable):** Para prevenir ataques de reutilización de nombres de cuentas o repositorios (*repo hijacking* / *namespace recycling*), GitHub agrega los identificadores numéricos únicos e inmutables del propietario y del repositorio:
  ```text
  repo:<usuario>@<owner_id>/<repo>@<repo_id>:ref:refs/heads/<rama>
  ```

Para el repositorio `kakulukiyam/agentes`:
* **Propietario / Owner ID:** `kakulukiyam` (`326736520`)
* **Repositorio / Repo ID:** `agentes` (`1462156195`)
* **Cadena del Claim `sub` emitida:** `repo:kakulukiyam@326736520/agentes@1462156195:ref:refs/heads/main`

Debido a que la política de confianza (*Trust Policy*) del rol IAM original únicamente permitía la cadena clásica o el repositorio anterior (`llorld43-gif/agentes`), AWS STS rechazaba criptográficamente la emisión de credenciales temporales.

---

## 2. Requisitos y Formato de Encabezado en GitHub Actions

Para que el consumo de tokens JWT sea aceptado por AWS STS, se requieren dos configuraciones clave en GitHub Actions:

### 2.1 Encabezado de Permisos en el Workflow
El archivo YAML de GitHub Actions debe declarar explícitamente permisos de escritura para `id-token` a nivel global o del trabajo:
```yaml
permissions:
  id-token: write # Permite al runner solicitar el token OIDC JWT a GitHub
  contents: read  # Permite clonar el código fuente
```

### 2.2 Parámetros de Autenticación OIDC
En el paso de autenticación con `aws-actions/configure-aws-credentials@v4`:
```yaml
- name: Autenticación con AWS vía OIDC (Sin llaves fijas)
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::037668896847:role/citas-escolares-github-oidc-role
    aws-region: us-east-1
    audience: sts.amazonaws.com # Estándar requerido por AWS STS
    role-session-name: GitHubActions-Infra
```

---

## 3. Fase de Bootstrap: Infraestructura Base para CI/CD

El módulo `bootstrap/` se encarga de aprovisionar los cimientos de la cuenta de AWS para operar sin secretos estáticos (`AWS_ACCESS_KEY_ID` ni `AWS_SECRET_ACCESS_KEY`).

### 3.1 Ajuste de la Política de Confianza de IAM
En `bootstrap/main.tf`, se configuró la condición `StringLike` para permitir de manera segura tanto el formato clásico como el inmutable:

```hcl
resource "aws_iam_role" "github_actions_role" {
  name = "${var.project_name}-github-oidc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_repo}:*",
              "repo:kakulukiyam/agentes:*",
              "repo:kakulukiyam@326736520/agentes@1462156195:*",
              "repo:llorld43-gif/agentes:*",
              "repo:llorld43-gif@307716463/agentes@1462154844:*"
            ]
          }
        }
      }
    ]
  })
}
```

### 3.2 Manejo del Proveedor OIDC Existente
En AWS IAM, solo puede existir **un único proveedor OIDC por URL**. Dado que `token.actions.githubusercontent.com` ya existía en la cuenta `037668896847`, se ejecutó una importación controlada al estado de Terraform para evitar el error `EntityAlreadyExists`:
```bash
terraform import aws_iam_openid_connect_provider.github_oidc arn:aws:iam::037668896847:oidc-provider/token.actions.githubusercontent.com
```

### 3.3 Despliegue del Bootstrap con Credenciales de `Terraform-Lab`
Utilizando las credenciales del usuario IAM local `Terraform-Lab` (Cuenta `037668896847`), se ejecutó:
```bash
cd bootstrap
terraform apply -auto-approve
```

#### Recursos Creados:
1. **Rol IAM OIDC:** `arn:aws:iam::037668896847:role/citas-escolares-github-oidc-role`
2. **Bucket S3 para Estado Remoto:** `citas-escolares-tfstate-btamu4` (con versionamiento y cifrado AES-256 habilitados)
3. **Tabla DynamoDB para Bloqueo de Estado:** `citas-escolares-tflocks`
4. **Permisos de Despliegue:** Asignación de políticas necesarias (`citas-escolares-pipeline-policy` y `AdministratorAccess`) para permitir el aprovisionamiento de CloudFront, API Gateway, S3, Cognito, Lambda y DynamoDB.

---

## 4. Configuración del Repositorio y Backend de Terraform

### 4.1 Backend Remoto de Terraform
En `terraform/provider.tf`, se configuró el backend S3 con los valores emitidos por el Bootstrap:

```hcl
terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "citas-escolares-tfstate-btamu4"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "citas-escolares-tflocks"
    encrypt        = true
  }
}
```

### 4.2 Sincronización del Remoto de Git
Se apuntó el remoto `origin` al repositorio de destino:
```bash
git remote set-url origin https://github.com/kakulukiyam/agentes.git
git push -u origin main
```

---

## 5. Ejecución del Pipeline CI/CD en GitHub Actions

El pipeline (`.github/workflows/deploy.yml`) se disparó de forma automatizada tras el push a la rama `main` (Run ID: **44652157069**).

### Fases Ejecutadas:

```
+-------------------------------------------------------------------------------+
|                      PIPELINE CI/CD SERVERLESS (OIDC)                         |
+-------------------------------------------------------------------------------+
|                                                                               |
|  [ Fase 1: Infraestructura (Terraform) ]                                     |
|  - Autenticación OIDC vía STS (Sin llaves fijas)                 --> SUCCESS  |
|  - Despliegue de S3, DynamoDB, Cognito, API Gateway, CloudFront --> SUCCESS  |
|                                                                               |
|  [ Fase 2: Backend (AWS Lambda) ]                                             |
|  - Empaquetado de backend/app.py                                 --> SUCCESS  |
|  - Actualización de función Lambda citas-escolares-backend-prod   --> SUCCESS  |
|                                                                               |
|  [ Fase 3: Frontend (S3 + CloudFront CDN) ]                                   |
|  - Inyección dinámica de frontend/config.js                      --> SUCCESS  |
|  - Sincronización de assets web al bucket S3                     --> SUCCESS  |
|  - Invalidación global de caché en CloudFront CDN                --> SUCCESS  |
|                                                                               |
|  [ Fase 4: Pruebas de Disponibilidad (Smoke Tests) ]                         |
|  - Verificación HTTP 200 en CloudFront                           --> SUCCESS  |
|  - Verificación de salud de API Gateway /health                  --> SUCCESS  |
|                                                                               |
+-------------------------------------------------------------------------------+
```

---

## 6. Endpoints y Verificación del Entorno en Producción

Los recursos quedaron completamente operativos en la región `us-east-1`:

| Recurso | Identificador / URL | Estado |
| :--- | :--- | :--- |
| **Aplicación Web (CloudFront CDN)** | `https://d3b88o446f5gfv.cloudfront.net` | **200 OK** |
| **API Gateway HTTP API v2** | `https://gk94yfqbyl.execute-api.us-east-1.amazonaws.com/` | **Activo** |
| **Endpoint de Salud (/health)** | `https://gk94yfqbyl.execute-api.us-east-1.amazonaws.com/health` | **`{"status":"healthy"}`** |
| **Cognito User Pool (Docentes)** | `us-east-1_YU5bnTmqp` | **Activo** |
| **Cognito App Client** | `5t9kdg96t7q3ir05q85718s049` | **Activo** |
| **Tabla DynamoDB (Citas)** | `citas-escolares-citas-prod` | **Activa** |
| **Bucket Frontend S3** | `citas-escolares-frontend-prod-nwsbbz` | **Activo (OAC)** |
| **Función AWS Lambda** | `citas-escolares-backend-prod` | **Activa (Python 3.11)** |

---

## 7. Buenas Prácticas y Mantenimiento Futuro

1. **Rotación Cero de Credenciales:** Gracias a OIDC, nunca es necesario generar, rotar ni almacenar llaves de acceso IAM en los secretos del repositorio.
2. **Nuevos Repositorios u Organizaciones:** Si se crea un nuevo repositorio en GitHub (posterior a julio de 2026), se debe obtener su identificador numérico consultando la API de GitHub (`https://api.github.com/repos/<owner>/<repo>`) y agregarlo a la condición `StringLike` en `bootstrap/main.tf`.
3. **Bloqueo Concurrente:** El backend S3 protegido con DynamoDB garantiza que múltiples ejecuciones del pipeline o comandos locales no puedan corromper el estado de la infraestructura.
