terraform {
  backend "s3" {
    region         = "${region}"
    bucket         = "${bucket}"
    key            = "${key}"
    encrypt        = ${encrypt}
    dynamodb_table = "${dynamodb_table}"
  }
}
