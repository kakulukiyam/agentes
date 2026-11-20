# ==============================================================================
# Amazon SES (Simple Email Service) - Notificaciones de Confirmación
# ==============================================================================
# Permite enviar hasta 62,000 correos salientes al mes sin costo
# Transmisión encriptada vía TLS y autenticación SPF/DKIM

resource "aws_ses_email_identity" "sender" {
  email = var.ses_sender_email
}
