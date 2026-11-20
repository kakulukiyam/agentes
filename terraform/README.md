# Sistema Escolar de Citas - Infraestructura Serverless con Terraform (IaC)

Este directorio contiene la Infraestructura como Código (IaC) para desplegar la solución completa en AWS a **Costo $0 USD (Free Tier)** con **Seguridad en Tránsito y en Reposo**.

## 📁 Arquitectura del Repositorio

```
agentes/
├── backend/                  # Lógica de Negocio Serverless (Python)
│   ├── app.py                # Handler de Lambda con bloqueo atómico en DynamoDB
│   ├── requirements.txt      # Dependencias nativas
│   └── README.md
│
├── frontend/                 # Aplicación Web Móvil (PWA)
│   ├── index.html            # Interfaz adaptativa para Acudientes y Docentes
│   ├── styles.css            # Estilos modernos táctiles
│   ├── app.js                # Cliente REST con detección de conflictos (409)
│   ├── config.js             # Variables de conexión generadas por Terraform
│   └── README.md
│
└── terraform/                # Código de Infraestructura AWS (Terraform)
    ├── provider.tf           # Proveedor AWS y versiones mínimas
    ├── variables.tf          # Variables parametrizables
    ├── dynamodb.tf           # Tabla NoSQL con candado atómico y KMS AES-256
    ├── cognito.tf            # Directorio de docentes y JWT con flujo SRP
    ├── s3_cloudfront.tf      # Alojamiento web, OAC y HTTPS TLS 1.3
    ├── api_gateway.tf        # HTTP API v2 con JWT Authorizer y Throttling
    ├── lambda.tf             # Empaqueta y despliega el código desde ../backend/
    ├── frontend_sync.tf      # Sube automáticamente ../frontend/ a S3 e inyecta config.js
    ├── ses.tf                # Notificaciones por correo electrónico
    ├── outputs.tf            # URLs de CloudFront, API Gateway y Cognito
    └── terraform.tfvars.example
```

## 🚀 Guía de Despliegue en 1 Solo Paso

### 1. Configuración de Credenciales
Asegúrate de tener configurado el AWS CLI con tus credenciales:
```bash
aws configure
```

### 2. Inicializar y Aplicar con Terraform
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

✨ **Despliegue 100% Automatizado:**
Al ejecutar `terraform apply`:
1. Empaqueta el backend desde `../backend/app.py` y lo publica en AWS Lambda.
2. Crea DynamoDB, Cognito, API Gateway y CloudFront.
3. Toma los archivos de `../frontend/` y los sube directamente al Bucket S3.
4. Genera dinámicamente el archivo `config.js` en S3 con la URL real de tu API Gateway y las credenciales de Cognito.
5. Al finalizar, la terminal te entregará la URL de CloudFront lista para abrir desde cualquier celular.
