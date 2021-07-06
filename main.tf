terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}
provider "azurerm"{
  features {}
}

data "azurerm_image" "image" {
  name                = "UdacityPackerImage"
  resource_group_name = "UdacityProject1"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
  tags = {
    environment = "${var.rg_tag}"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/22"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags = {
    environment = "UdacityProject1"
  }
}

resource "azurerm_subnet" "main" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = {
    Resource = "UdacityProject1"
  }
}


# Security group to deny inbound traffic from Internet
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-sg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

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
  tags = {
    environment = "UdacityProject1"
  }
}  
resource "azurerm_public_ip" "main" {
  count                   = "${var.countVm}"
  name                    = "${var.prefix}-PublicIp"
  resource_group_name     = azurerm_resource_group.main.name
  location                = "${var.location}"
  allocation_method       = "Static"
  tags = {
    environment = "UdacityProject1"
  }
}

resource "azurerm_virtual_machine" "main" {
  count                           = "${var.countVm}"
  name                            = "${var.prefix}-vm"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  vm_size                         = "Standard_D2s_v3"
  
  
  network_interface_ids = [
    azurerm_network_interface.main.id
  ]
  storage_image_reference {
    id = "${var.imageID}"
  }

  storage_os_disk {
    name               = "${var.prefix}-osDisk"
    caching            = "ReadWrite"
    create_option      = "FromImage"
  }
  tags = {
    Resource = "UdacityProject1"
  }
}






