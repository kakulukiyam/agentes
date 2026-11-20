# ==============================================================================
# Outputs de Infraestructura - Datos de Conexión para Frontend y Operaciones
# ==============================================================================

output "cloudfront_url" {
  description = "URL pública segura (HTTPS) para que acudientes y docentes abran la Web App"
  value       = "https://${aws_cloudfront_distribution.cdn.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "ID de la distribución de CloudFront para invalidación de caché"
  value       = aws_cloudfront_distribution.cdn.id
}

output "api_gateway_url" {
  description = "URL base del API Gateway HTTP para el frontend"
  value       = aws_apigatewayv2_stage.default_stage.invoke_url
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 para desplegar los archivos de la app (npm run build -> s3 sync)"
  value       = aws_s3_bucket.frontend.id
}

output "cognito_user_pool_id" {
  description = "ID del User Pool de Cognito para autenticación de profesores"
  value       = aws_cognito_user_pool.docentes.id
}

output "cognito_app_client_id" {
  description = "ID del Cliente de Cognito para configurar en el frontend móvil"
  value       = aws_cognito_user_pool_client.app_client.id
}

output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB con bloqueo atómico anti-cruces"
  value       = aws_dynamodb_table.citas.name
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda de backend"
  value       = aws_lambda_function.api_backend.function_name
}
