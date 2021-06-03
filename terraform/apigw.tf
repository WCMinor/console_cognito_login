data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_apigatewayv2_api" "get_console" {
  name          = "${var.user_pool_name}-get-console"
  protocol_type = "HTTP"
  #We need to "harcode" this ARN instead of using the Terraform resource to avoid
  #a terraform cycle condition, however, the target can be created before the
  #lamba itself, it works ok
  target = "arn:aws:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.id}:function:${var.user_pool_name}-getCredentials"
}
