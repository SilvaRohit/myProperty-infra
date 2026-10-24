resource "aws_eip_association" "existing_property_app" {
  count              = var.associate_elastic_ip ? 1 : 0
  provider           = aws.existing
  allocation_id      = var.elastic_ip_allocation_id
  instance_id        = aws_instance.property_app.id
  private_ip_address = aws_instance.property_app.private_ip
}
