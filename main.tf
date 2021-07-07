##############################################################################
# * HashiCorp Beginner's Guide to Using Terraform on Azure
# 
# This Terraform configuration will create the following:
#
# Resource group with a virtual network and subnet
# An Ubuntu Linux server running Apache

##############################################################################
# * Shared infrastructure resources

# The latest version of the Azure provider breaks backward compatibility.
# TODO: Update this code to use the latest provider.
provider "azurerm" {
  version = "=1.44.0"
}

# data "azurerm_image" "image" {
#   name                = "HWPackerImage"
#   resource_group_name = "Terraform-Azure-Beginners"
# }
# First we'll create a resource group. In Azure every resource belongs to a 
# resource group. Think of it as a container to hold all your resources. 
# You can find a complete list of Azure resources supported by Terraform here:
# https://www.terraform.io/docs/providers/azurerm/
resource "azurerm_resource_group" "tf_azure_guide" {
  name     = "${var.resource_group}"
  location = "${var.location}"
  tags = {
    environment = "${var.rg_tag}"
  }
}

# The next resource is a Virtual Network. We can dynamically place it into the
# resource group without knowing its name ahead of time. Terraform handles all
# of that for you, so everything is named consistently every time. Say goodbye
# to weirdly-named mystery resources in your Azure Portal. To see how all this
# works visually, run `terraform graph` and copy the output into the online
# GraphViz tool: http://www.webgraphviz.com/
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.virtual_network_name}"
  location            = "${azurerm_resource_group.tf_azure_guide.location}"
  address_space       = ["${var.address_space}"]
  resource_group_name = "${azurerm_resource_group.tf_azure_guide.name}"
  tags = {
    environment = "${var.rg_tag}"
  }
}

# Next we'll build a subnet to run our VMs in. These variables can be defined 
# via environment variables, a config file, or command line flags. Default 
# values will be used if the user does not override them. You can find all the
# default variables in the variables.tf file. You can customize this demo by
# making a copy of the terraform.tfvars.example file.
resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}subnet"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${azurerm_resource_group.tf_azure_guide.name}"
  address_prefix       = "${var.subnet_prefix}"
}

##############################################################################
# * Build an Ubuntu 16.04 Linux VM
#
# Now that we have a network, we'll deploy an Ubuntu 16.04 Linux server.
# An Azure Virtual Machine has several components. In this example we'll build
# a security group, a network interface, a public ip address, a storage 
# account and finally the VM itself. Terraform handles all the dependencies 
# automatically, and each resource is named with user-defined variables.

# Security group to allow inbound access on port 80 (http) and 22 (ssh)
resource "azurerm_network_security_group" "tf-guide-sg" {
  name                = "${var.prefix}-sg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.tf_azure_guide.name}"

  security_rule {
    name                       = "DenyInternetInBound"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "VirtualNetwork"
  }

}

# A network interface. This is required by the azurerm_virtual_machine 
# resource. Terraform will let you know if you're missing a dependency.
resource "azurerm_network_interface" "tf-guide-nic" {
  name                      = "${var.prefix}tf-guide-nic"
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.tf_azure_guide.name}"
  network_security_group_id = "${azurerm_network_security_group.tf-guide-sg.id}"

  ip_configuration {
    name                          = "${var.prefix}ipconfig"
    subnet_id                     = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation = "Dynamic"
    
  }
  tags = {
    environment = "${var.rg_tag}"
  }
}
resource "azurerm_managed_disk" "tf-guide-md" {
  count                   = "${var.countVm}"
  name                    = "${var.prefix}-md"
  location                = "${var.location}"
  resource_group_name     = "${azurerm_resource_group.tf_azure_guide.name}"
  storage_account_type    = "Standard_LRS"
  create_option           = "Empty"
  disk_size_gb            = "1"

  tags = {
    environment = "${var.rg_tag}"
  }
}
# Every Azure Virtual Machine comes with a private IP address. You can also 
# optionally add a public IP address for Internet-facing applications and 
# demo environments like this one.
resource "azurerm_public_ip" "tf-guide-pip" {
  # count                        = "${var.countVm}"
  name                         = "${var.prefix}-ip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.tf_azure_guide.name}"
  public_ip_address_allocation = "Dynamic"
  domain_name_label            = "${var.hostname}"
}
# resource "azurerm_network_interface_security_group_association" "tf-guide-nis" {
#   count                          = "${var.countVm}"
#   network_interface_id =    azurerm_network_interface.tf-guide-nic.id
#   network_security_group_id      = azurerm_network_security_group.tf-guide-sg.id
  
# }
resource "azurerm_lb" "tf-guide-lb" {
  count                   = "${var.countVm}"
  name                = "${var.prefix}-lb"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.tf_azure_guide.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.tf-guide-pip[count.index].id
  }
  tags = {
    Resource = "${var.rg_tag}"
  }
}
resource "azurerm_lb_backend_address_pool" "tf-guide-lbBackendpool" {
  count                   = "${var.countVm}"
  resource_group_name             = "${azurerm_resource_group.tf_azure_guide.name}"
  loadbalancer_id                 = azurerm_lb.tf-guide-lb[count.index].id
  name                            = "${var.prefix}-lbBackendpool"
  
}
resource "azurerm_network_interface_backend_address_pool_association" "tf-guide-bakendpoolassoci"{
  count                    = "${var.countVm}"
  network_interface_id     = azurerm_network_interface.tf-guide-nic.id
  ip_configuration_name    = "UdProConfiguration"
  backend_address_pool_id  = azurerm_lb_backend_address_pool.tf-guide-lbBackendpool[count.index].id
  
}
resource "azurerm_lb_probe" "main" {
  count               = "${var.countVm}"
  resource_group_name = "${azurerm_resource_group.tf_azure_guide.name}"
  loadbalancer_id     = azurerm_lb.tf-guide-lb[count.index].id
  name                = "${var.prefix}-lbprobe"
  port                = "80"
  
}
# And finally we build our virtual machine. This is a standard Ubuntu instance.
# We use the shell provisioner to run a Bash script that configures Apache for 
# the demo environment. Terraform supports several different types of 
# provisioners including Bash, Powershell and Chef.
resource "azurerm_virtual_machine" "site" {
  count              = "${var.countVm}"
  name                = "${var.hostname}-site"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.tf_azure_guide.name}"
  vm_size             = "${var.vm_size}"

  network_interface_ids         = ["${azurerm_network_interface.tf-guide-nic.id}"]
  delete_os_disk_on_termination = "true"

  storage_image_reference {
    id = "${var.imageID}"
  }

  storage_os_disk {
    name              = "${var.hostname}-osdisk"
    managed_disk_type = "Standard_LRS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }
  os_profile {
    computer_name  = "${var.hostname}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "${var.rg_tag}"
  }

  # It's easy to transfer files or templates using Terraform.
  # provisioner "file" {
  #   source      = "files/setup.sh"
  #   destination = "/home/${var.admin_username}/setup.sh"

  #   connection {
  #     type     = "ssh"
  #     user     = "${var.admin_username}"
  #     password = "${var.admin_password}"
  #     host     = "${azurerm_public_ip.tf-guide-pip[count.index].fqdn}"
  #   }
  # }

  # This shell script starts our Apache server and prepares the demo environment.
  # provisioner "remote-exec" {
  #   inline = [
  #     "chmod +x /home/${var.admin_username}/setup.sh",
  #     "sudo /home/${var.admin_username}/setup.sh",
  #   ]

  #   connection {
  #     type     = "ssh"
  #     user     = "${var.admin_username}"
  #     password = "${var.admin_password}"
  #     host     = "${azurerm_public_ip.tf-guide-pip[count.index].fqdn}"
  #   }
  # }
}

