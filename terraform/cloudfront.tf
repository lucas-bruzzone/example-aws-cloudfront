# CloudFront Distribution
resource "aws_cloudfront_distribution" "website" {
  # Origem S3
  origin {
    domain_name              = data.aws_s3_bucket.website.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
    origin_id                = "S3-${data.aws_s3_bucket.website.bucket}"
  }

  # Origem API (condicional)
  dynamic "origin" {
    for_each = length(data.terraform_remote_state.api_rest.outputs) > 0 ? [1] : []
    content {
      domain_name = split("/", replace(data.terraform_remote_state.api_rest.outputs.api_gateway_url, "https://", ""))[0]
      origin_id   = "API-${var.project_name}"
      origin_path = "/${var.environment}"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} ${var.environment} CloudFront"
  default_root_object = "index.html"

  # Domínios alternativos (apenas se certificado existir)
  aliases = var.domain_name != "" ? [var.domain_name, "www.${var.domain_name}"] : []

  # Comportamento padrão (website)
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${data.aws_s3_bucket.website.bucket}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Comportamento para API (condicional)
  dynamic "ordered_cache_behavior" {
    for_each = length(data.terraform_remote_state.api_rest.outputs) > 0 ? [1] : []
    content {
      path_pattern           = "/api/*"
      allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods         = ["GET", "HEAD"]
      target_origin_id       = "API-${var.project_name}"
      viewer_protocol_policy = "redirect-to-https"
      compress               = true

      forwarded_values {
        query_string = true
        headers      = ["Authorization", "Content-Type"]
        cookies {
          forward = "none"
        }
      }

      min_ttl     = 0
      default_ttl = 0
      max_ttl     = 0
    }
  }

  # Páginas de erro customizadas
  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/error.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/error.html"
  }

  # Configuração SSL
  viewer_certificate {
    acm_certificate_arn            = var.domain_name != "" ? aws_acm_certificate.website[0].arn : null
    ssl_support_method             = var.domain_name != "" ? "sni-only" : null
    minimum_protocol_version       = var.domain_name != "" ? "TLSv1.2_2021" : null
    cloudfront_default_certificate = var.domain_name == "" ? true : null
  }

  # Restrições geográficas
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "${var.project_name}-cloudfront"
  }
}