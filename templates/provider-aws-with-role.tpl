provider "aws" {
    region = "${region}"
    allowed_account_ids = ["${account_id}"]
    assume_role {
      role_arn = "${role_arn}"
    }
}
