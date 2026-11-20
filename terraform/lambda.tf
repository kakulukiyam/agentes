# ==============================================================================
# AWS Lambda - Backend Serverless para Lógica de Negocio y Bloqueo Atómico
# ==============================================================================
# 1,000,000 de invocaciones y 3.2M de segundos de cómputo mensuales GRATIS de por vida

# Empaquetado automático del código Python desde la carpeta ../backend
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../backend/app.py"
  output_path = "${path.module}/lambda_dist/app.zip"
}

# 1. Rol IAM con Principio de Menor Privilegio (Least Privilege)
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Security = "IAM-Least-Privilege"
  }
}

# 2. Política IAM Granular: CloudWatch, DynamoDB (Put/Get/Query) y SES
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.project_name}-lambda-policy-${var.environment}"
  description = "Permisos granulares para operar la base de datos de citas y enviar notificaciones"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Escritura de Logs en CloudWatch para auditoría
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      # Permisos en la tabla DynamoDB de Citas
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          aws_dynamodb_table.citas.arn,
          "${aws_dynamodb_table.citas.arn}/*"
        ]
      },
      # Permiso para enviar correos transaccionales por Amazon SES
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# 3. Función AWS Lambda
resource "aws_lambda_function" "api_backend" {
  function_name = "${var.project_name}-backend-${var.environment}"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "app.handler"
  runtime       = "python3.11"
  timeout       = 10
  memory_size   = 128 # Máxima economía y dentro de Free Tier

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # SEGURIDAD EN REPOSO: Variables de entorno encriptadas
  environment {
    variables = {
      TABLE_NAME   = aws_dynamodb_table.citas.name
      SENDER_EMAIL = var.ses_sender_email
      ENVIRONMENT  = var.environment
    }
  }

  tags = {
    Name     = "${var.project_name}-lambda-backend"
    Security = "MicroVM-Isolated-Firecracker"
  }
}

# 4. Permiso para que API Gateway invoque la función Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
