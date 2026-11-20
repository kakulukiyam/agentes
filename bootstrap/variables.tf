variable "aws_region" {
  description = "Región de AWS donde se creará el bootstrap y la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo para nombrar los recursos de bootstrap"
  type        = string
  default     = "citas-escolares"
}

variable "github_repo" {
  description = "Repositorio de GitHub en formato 'usuario_u_organizacion/nombre_del_repo' (Ej: 'mi-colegio/citas-serverless')"
  type        = string
  default     = "tu-organizacion/citas-escolares"
}

variable "github_branch" {
  description = "Rama principal que ejecutará el pipeline de despliegue"
  type        = string
  default     = "main"
}
