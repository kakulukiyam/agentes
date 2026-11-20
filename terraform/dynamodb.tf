# ==============================================================================
# Amazon DynamoDB - Tabla Principal de Citas y Horarios
# ==============================================================================
# Modo Aprovisionado (5 RCU / 5 WCU) para garantizar Costo $0 en Free Tier
# (El Free Tier perpetuo de AWS cubre hasta 25 RCU y 25 WCU y 25 GB)

resource "aws_dynamodb_table" "citas" {
  name         = "${var.project_name}-citas-${var.environment}"
  billing_mode = "PROVISIONED"

  read_capacity  = 5
  write_capacity = 5

  # Partition Key: DOCENTE#<teacher_id> o CONFIG#...
  hash_key = "PK"
  # Sort Key: SLOT#<fecha>#<hora> o METADATA
  range_key = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # Cifrado en reposo mediante claves maestras de AWS KMS (AES-256 sin costo)
  server_side_encryption {
    enabled = true
  }

  # TTL opcional para depuración automática de citas pasadas si se requiere
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Punto de recuperación en el tiempo (PITR) para respaldos automáticos
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-citas-db"
    Security    = "Encrypted-At-Rest-AES256"
    Concurrency = "AtomicConditionalWrites"
  }
}
