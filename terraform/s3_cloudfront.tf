# ==============================================================================
# Amazon S3 & CloudFront - Alojamiento Seguro de la Web App Móvil
# ==============================================================================
# S3 + CloudFront permite alojar la aplicación con costo $0 dentro del Free Tier
# CloudFront incluye 1 TB de salida y HTTPS global gratuito

resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Bucket de S3 para los archivos estáticos de la aplicación (HTML, JS, CSS)
resource "aws_s3_bucket" "frontend" {
  bucket        = "${var.project_name}-frontend-${var.environment}-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-frontend-bucket"
    Environment = var.environment
  }
}

# 1. SEGURIDAD EN REPOSO: Cifrado transparente con AES-256 en S3
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 2. SEGURIDAD: Bloqueo de Todo Acceso Público Directo al Bucket
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. Control de Acceso de Origen (Origin Access Control - OAC) para CloudFront
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}-oac-${var.environment}"
  description                       = "OAC para permitir acceso exclusivo desde CloudFront hacia S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 4. Distribución de Amazon CloudFront
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "CDN para App de Citas Escolares"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # SEGURIDAD EN TRÁNSITO: Redirección obligatoria a HTTPS (TLS 1.2 / 1.3)
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Manejo de rutas para Single Page Apps (SPA - React/Vue)
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Certificado SSL/TLS administrado gratuito de CloudFront (*.cloudfront.net)
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = {
    Name     = "${var.project_name}-cdn"
    Security = "HTTPS-Redirect-TLS1.3"
  }
}

# 5. Política del Bucket S3: Permite solo CloudFront y RECHAZA conexiones HTTP no seguras
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Permitir lectura solo desde CloudFront vía OAC
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      },
      # SEGURIDAD EN TRÁNSITO: Denegar explícitamente cualquier petición sin HTTPS
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.frontend.arn,
          "${aws_s3_bucket.frontend.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
