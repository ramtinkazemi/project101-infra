provider "aws" {
    region = "${region}"
    allowed_account_ids = ["${account_id}"]
}
