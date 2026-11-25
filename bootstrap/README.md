# Fase de Bootstrap: Autenticación OIDC y Backend Remoto

Este módulo implementa el estándar recomendado por AWS para despliegues de CI/CD: **OpenID Connect (OIDC)** con GitHub Actions.

## 🎯 Beneficios de OIDC frente a Access Keys
1. **Sin contraseñas fijas:** No almacenas `AWS_ACCESS_KEY_ID` ni `AWS_SECRET_ACCESS_KEY` en los secretos de GitHub.
2. **Tokens Temporales de Corta Duración:** AWS genera credenciales criptográficas válidas solo por 1 hora durante la ejecución del job.
3. **Restricción por Repositorio:** Únicamente los flujos de trabajo que provienen de tu repositorio y rama autorizada pueden asumir el rol.

---

## 🚀 Despliegue de Bootstrap (Solo 1 vez)

### 1. Configurar variables
Edita `variables.tf` o pasa tus parámetros (por defecto autoriza **todos** los repositorios del propietario `github_owner` / `github_owner_id` tanto en formato clásico como inmutable):
```bash
cd bootstrap
terraform init
terraform apply -var="github_owner=tu-usuario" -var="github_owner_id=tu-owner-id"
```

### 2. Guardar Outputs
Al finalizar, copia los 3 valores que arroja la terminal:
- `github_actions_role_arn`: Pégalo en tu repositorio de GitHub en **Settings > Secrets and variables > Actions > Variables** con el nombre `AWS_ROLE_ARN`.
- `terraform_state_bucket` y `terraform_lock_table`: Úsalos para configurar el backend remoto en `terraform/provider.tf`.
