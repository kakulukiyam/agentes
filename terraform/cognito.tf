# ==============================================================================
# Amazon Cognito - Directorio y Autenticación para Docentes
# ==============================================================================
# Gratuito hasta 50,000 Usuarios Activos Mensuales (MAU) en Free Tier Perpetuo

resource "aws_cognito_user_pool" "docentes" {
  name = "${var.project_name}-docentes-pool-${var.environment}"

  # Inicio de sesión con correo institucional
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Políticas de contraseña segura
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # Configuración de recuperación de cuenta vía email
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Atributos personalizados para la materia o departamento del docente
  schema {
    attribute_data_type = "String"
    name                = "materia"
    mutable             = true
    required            = false
    string_attribute_constraints {
      min_length = 1
      max_length = 100
    }
  }

  tags = {
    Name     = "${var.project_name}-cognito-pool"
    Security = "SRP-JWT-Encrypted"
  }
}

# Cliente para la Aplicación Móvil / PWA de los Profesores
resource "aws_cognito_user_pool_client" "app_client" {
  name         = "${var.project_name}-web-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.docentes.id

  # Las aplicaciones de navegador / SPA no deben usar secret por seguridad
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]

  # Duración de los tokens
  id_token_validity      = 60 # Minutos
  access_token_validity  = 60 # Minutos
  refresh_token_validity = 30 # Días

  token_validity_units {
    id_token      = "minutes"
    access_token  = "minutes"
    refresh_token = "days"
  }

  prevent_user_existence_errors = "ENABLED"
}
