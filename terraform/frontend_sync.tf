# ==============================================================================
# Sincronización Automática del Frontend hacia Amazon S3
# ==============================================================================
# Sube los archivos HTML, CSS y JS desde la carpeta ../frontend hacia el bucket S3
# e inyecta dinámicamente las URLs del API Gateway y Cognito en config.js

locals {
  frontend_files = {
    "index.html" = "text/html"
    "styles.css" = "text/css"
    "app.js"     = "application/javascript"
  }
}

# 1. Subida de archivos estáticos base (HTML, CSS, JS)
resource "aws_s3_object" "frontend_assets" {
  for_each = local.frontend_files

  bucket       = aws_s3_bucket.frontend.id
  key          = each.key
  source       = "${path.module}/../frontend/${each.key}"
  etag         = filemd5("${path.module}/../frontend/${each.key}")
  content_type = each.value

  # Seguridad en reposo
  server_side_encryption = "AES256"
}

# 2. Generación e inyección automática de config.js en S3 con los datos de AWS
resource "aws_s3_object" "frontend_config" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "config.js"
  content_type = "application/javascript"

  content = <<-EOT
    // Archivo de configuración generado automáticamente por Terraform
    window.APP_CONFIG = {
      API_BASE_URL: "${aws_apigatewayv2_stage.default_stage.invoke_url}",
      COGNITO_USER_POOL_ID: "${aws_cognito_user_pool.docentes.id}",
      COGNITO_CLIENT_ID: "${aws_cognito_user_pool_client.app_client.id}",
      AWS_REGION: "${var.aws_region}",
      USE_MOCK_FALLBACK: false
    };
  EOT

  # Seguridad en reposo
  server_side_encryption = "AES256"

  depends_on = [
    aws_apigatewayv2_stage.default_stage,
    aws_cognito_user_pool_client.app_client
  ]
}
