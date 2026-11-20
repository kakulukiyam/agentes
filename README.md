# Sistema Escolar de Citas - Infraestructura Serverless CI/CD

Sistema web serverless para la gestión de citas escolares (acudientes y docentes) desplegado en AWS a través de Terraform y GitHub Actions utilizando autenticación OIDC sin llaves estáticas.

## 📖 Documentación del Proceso
Para consultar el detalle completo de arquitectura, diagnóstico del formato OIDC de GitHub Actions, despliegue del Bootstrap y ejecución del pipeline, consulta:
👉 **[Guía de Proceso de Punta a Punta (OIDC & CI/CD)](PROCESO_DESPLIEGUE_OIDC_CI_CD.md)**

## 🚀 Enlaces de Producción
* **Frontend Web (CloudFront CDN):** [https://d3b88o446f5gfv.cloudfront.net](https://d3b88o446f5gfv.cloudfront.net)
* **API Gateway HTTP API:** `https://gk94yfqbyl.execute-api.us-east-1.amazonaws.com/`
* **Salud de la API (/health):** `https://gk94yfqbyl.execute-api.us-east-1.amazonaws.com/health`
