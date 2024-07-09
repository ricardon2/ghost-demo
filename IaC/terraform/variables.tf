variable "env_prefix" {
  default     = "ghostpoc"
  description = "Environment prefix, no alpha numeric characters"
}

variable "mysql_administrator_login" {
  description = "Username to authenticate with mysql"
}

variable "mysql_administrator_login_password" {
  description = "Password of the host to access the database"
}