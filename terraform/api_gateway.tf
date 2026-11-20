# ==============================================================================
# Amazon API Gateway (HTTP API v2) - Entrada Segura y Económica
# ==============================================================================
# 1,000,000 de solicitudes gratis los primeros 12 meses, luego solo $1.00 por millón

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  description   = "API Gateway HTTP para gestión de citas escolares con autenticación JWT"

  # Configuración CORS para clientes web y móviles
  cors_configuration {
    allow_credentials = false
    allow_headers     = ["Content-Type", "Authorization", "X-Amz-Date"]
    allow_methods     = ["GET", "POST", "DELETE", "OPTIONS"]
    allow_origins     = var.cors_allowed_origins
    max_age           = 3600
  }

  tags = {
    Name     = "${var.project_name}-api"
    Security = "TLS1.3-HTTPS-Enforced"
  }
}

# 1. Authorizer Nativo de Cognito para API Gateway (Valida JWT RS256 en el borde)
resource "aws_apigatewayv2_authorizer" "cognito_jwt" {
  api_id           = aws_apigatewayv2_api.http_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-docente-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.app_client.id]
    issuer   = "https://${aws_cognito_user_pool.docentes.endpoint}"
  }
}

# 2. Integración Lambda (Proxy)
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_backend.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# 3. Rutas Públicas para Acudientes (Consulta y Reserva sin Login)
resource "aws_apigatewayv2_route" "get_health" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "get_docentes" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /docentes"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "get_slots" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /slots"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "post_citas" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /citas"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# 4. Ruta Privada para Docentes (Protegida por Cognito JWT)
# Cada docente solo puede acceder si presenta su token válido
resource "aws_apigatewayv2_route" "get_docente_citas" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "GET /docente/citas"
  target             = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_route" "delete_docente_citas" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "DELETE /docente/citas"
  target             = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

# 5. Despliegue Automático (Stage $default) con Protección de Costos (Throttling)
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  # PROTECCIÓN DE PRESUPUESTO & MITIGACIÓN DDOS: Limita peticiones por segundo
  default_route_settings {
    throttling_burst_limit = 50
    throttling_rate_limit  = 20
  }

  tags = {
    Environment = var.environment
  }
}
