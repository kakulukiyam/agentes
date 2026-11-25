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
  description = "Repositorio de GitHub principal en formato 'usuario_u_organizacion/nombre_del_repo' (Ej: 'mi-colegio/citas-serverless')"
  type        = string
  default     = "kakulukiyam/agentes"
}

variable "github_owner" {
  description = "Usuario u organización de GitHub cuyos repositorios tendrán acceso mediante OIDC"
  type        = string
  default     = "kakulukiyam"
}

variable "github_owner_id" {
  description = "ID numérico inmutable del propietario en GitHub para el formato de claim 'sub' (posterior a julio 2026)"
  type        = string
  default     = "326736520"
}

variable "github_branch" {
  description = "Rama principal que ejecutará el pipeline de despliegue"
  type        = string
  default     = "main"
}
