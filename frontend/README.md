# Frontend Móvil - Single Page Application (PWA)

Interfaz web ligera y responsive diseñada para abrirse directamente desde el navegador de cualquier teléfono celular sin necesidad de descargas desde tiendas de aplicaciones.

## Archivos
- `index.html`: Estructura semántica con vistas alternables de Acudiente y Docente.
- `styles.css`: Diseño moderno adaptativo con soporte para pantallas táctiles.
- `app.js`: Cliente de API REST con manejo de slots, bloqueo de concurrencia y agenda de profesores.
- `config.js`: Parámetros de conexión a AWS (se actualiza automáticamente al desplegar con Terraform).

## Despliegue en AWS S3
Para subir estos archivos al bucket S3 configurado por Terraform:
```bash
aws s3 sync ./ s3://<s3_bucket_name_output> --exclude "README.md" --delete
```
