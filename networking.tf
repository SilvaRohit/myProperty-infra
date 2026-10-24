resource "aws_eip" "existing_property_app" {
  provider = aws.existing
  domain   = "vpc"

  lifecycle {
    prevent_destroy = true
  }
}
