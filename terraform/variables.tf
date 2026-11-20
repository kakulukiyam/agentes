variable "aws_region" {
  description = "Región de AWS donde se desplegarán los recursos"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre base del proyecto para nombrar recursos"
  type        = string
  default     = "citas-escolares"
}

variable "environment" {
  description = "Entorno de despliegue (dev, qa, prod)"
  type        = string
  default     = "prod"
}

variable "ses_sender_email" {
  description = "Correo electrónico verificado en Amazon SES para enviar confirmaciones"
  type        = string
  default     = "notificaciones@colegio.edu"
}

variable "cors_allowed_origins" {
  description = "Orígenes permitidos para CORS en API Gateway"
  type        = list(string)
  default     = ["*"]
}
