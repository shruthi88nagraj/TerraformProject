variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
  default = "UdacityProject1"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default = "WestUS"
}

variable "countVm" { 
   description = "Number of VM instances"  
  default = "2"
}

variable "VM_user_names" {
 description = "Create VM's with these user names"
 default = ["UdacityVm1", "UdacityVm2"]
}

variable "username" {
  description = "Username"
  default = "shruthi.setty@outlook.com"
}

variable "password" {
  description = "user password"
  default = "Chocolate2@21"
}

variable "rg_tag" {
  description = "Adding resource group tag name as Project name"
  default = "UdacityProject1"
}

variable "imageID"{
  description = "Image ID of Virtual machines created by Packer"
  default = "/subscriptions/1a5cb3ad-7223-4fb6-8af0-84e5e06ede37/resourceGroups/UdacityProject2/providers/Microsoft.Compute/images/UdacityPackerImage"
}
