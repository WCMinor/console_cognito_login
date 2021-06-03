variable "user_pool_name" {
  type        = string
  description = "Name of the cognito user pool"
}

variable "student_role_allowed_groups" {
  type    = list(any)
  default = []
}
variable "admin_role_allowed_groups" {
  type    = list(any)
  default = []
}
