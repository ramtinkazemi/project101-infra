### ---------------------------------------------------------------------------------------------------------------------
### This file defines the terragrunt dependencies for this component.
### ---------------------------------------------------------------------------------------------------------------------

dependencies {
  paths = ["../network", "../eks"]
}

dependency "network" {
  config_path = find_in_parent_folders("network")

  // # Add mock outputs for the network module
  // mock_outputs = {
  //   vpc_id   = "mock-vpc-id"
  //   private_subnet_ids = "mock-subnet-ids"    
  //   public_subnet_ids = "mock-subnet-ids"    
  // }
  // skip_outputs = true  
}

dependency "eks" {
  config_path = find_in_parent_folders("eks")
  // skip_outputs = true  
}