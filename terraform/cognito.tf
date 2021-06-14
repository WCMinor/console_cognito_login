resource "aws_cognito_user_pool" "pool" {
  name = "${var.user_pool_name}-pool"
  lambda_config {
    pre_token_generation = aws_lambda_function.pre_token_generation.arn
  }
  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "groups"
    required                 = false

    string_attribute_constraints {
      max_length = "256"
      min_length = "1"
    }
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.user_pool_name
  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_user_pool_client" "client" {
  name            = "${var.user_pool_name}-client"
  callback_urls   = ["${aws_apigatewayv2_api.get_console.api_endpoint}/console"]
  user_pool_id    = aws_cognito_user_pool.pool.id
  generate_secret = true
  supported_identity_providers = [
    "COGNITO",
    "AzureAD"
  ]
  explicit_auth_flows = [
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]
  allowed_oauth_flows = [
    "code",
  ]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes = [
    "openid",
    "profile",
  ]

}

resource "aws_cognito_identity_pool" "main" {
  identity_pool_name               = "${var.user_pool_name}-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.client.id
    provider_name           = aws_cognito_user_pool.pool.endpoint
    server_side_token_check = false
  }
}

resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.main.id

  #The following field is mandatory but is not really used since we are usding ambiguous_role_resolution = "Deny" 
  roles = {
    "authenticated" = aws_iam_role.student_role.arn
  }

  role_mapping {
    identity_provider         = "${aws_cognito_user_pool.pool.endpoint}:${aws_cognito_user_pool_client.client.id}"
    ambiguous_role_resolution = "Deny"
    type                      = "Rules"
    #Dynamic role mapping rule to create all groups allowed to assume the student. role This is just an example.
    dynamic "mapping_rule" {
      for_each = toset(var.student_role_allowed_groups)
      content {
        claim      = "groups"
        match_type = "Contains"
        role_arn   = aws_iam_role.student_role.arn
        value      = mapping_rule.key
      }
    }
    #Dynamic role mapping rule to create all groups allowed to assume the admin role. This is just an example.
    dynamic "mapping_rule" {
      for_each = toset(var.admin_role_allowed_groups)
      content {
        claim      = "groups"
        match_type = "Contains"
        role_arn   = aws_iam_role.admin_role.arn
        value      = mapping_rule.key
      }
    }
  }
}


resource "aws_cognito_identity_provider" "azure_ad" {
  user_pool_id  = aws_cognito_user_pool.pool.id
  provider_name = "AzureAD"
  provider_type = "SAML"

  provider_details = {
    IDPSignout            = "false"
    MetadataURL           = var.AzureADMetadataURL
    SLORedirectBindingURI = var.AzureRedirectBindingURI
    SSORedirectBindingURI = var.AzureRedirectBindingURI
  }

  attribute_mapping = {
    "custom:groups" = "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups"
    email           = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
    given_name      = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"
    name            = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
  }
}
