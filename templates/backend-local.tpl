terraform {
    backend "local" {
        path = "../../../${path}"
    }
}
