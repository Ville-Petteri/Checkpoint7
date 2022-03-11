# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.12"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

resource "azurerm_resource_group" "terraform-checkpoint7-rg" {
      name     = var.resource_group_name
      location = var.region
}

# Create a virtual network
resource "azurerm_virtual_network" "terraform-checkpoint7-vnet" {
    name                = "Ville-Petteri-checkpoint7-vnet"
    address_space       = ["10.0.0.0/16"]
    location            = var.region
    resource_group_name = azurerm_resource_group.terraform-checkpoint7-rg.name

}

resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.terraform-checkpoint7-rg.name
  virtual_network_name = azurerm_virtual_network.terraform-checkpoint7-vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_network_security_group" "nsg-subnet1" {
  name                = "nsg-subnet1"
  location            = var.region
  resource_group_name = azurerm_resource_group.terraform-checkpoint7-rg.name

  security_rule {
    name                       = "allow_ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"

    }

security_rule {
    name                       = "allow_http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"

    }
}
resource "azurerm_subnet_network_security_group_association" "nsg-subnet1-association" {
  subnet_id                 = azurerm_subnet.subnet1.id
  network_security_group_id = azurerm_network_security_group.nsg-subnet1.id
}

resource "azurerm_linux_virtual_machine" "VM01" {
  name                            = "ls01"
  resource_group_name             = var.resource_group_name
  location                        = var.region
  size                            = "Standard_D2_v2"
  admin_username                  = "ville-petteri"
  admin_password                  = var.vm_password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.VM01-nic.id,
  ]
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

resource "azurerm_network_interface" "VM01-nic" {
  name                = "LS01-nic"
  resource_group_name = var.resource_group_name
  location            = var.region

  ip_configuration {
    name                          = "subnet1"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.VM01-pip.id
  }
}

resource "azurerm_public_ip" "VM01-pip" {
  name                = "LS01-pip"
  resource_group_name = var.resource_group_name
  location            = var.region
  allocation_method   = "Static"
}

resource "azurerm_virtual_machine_extension" "VM01-vme" {
  virtual_machine_id         = azurerm_linux_virtual_machine.VM01.id
  name                       = "LS01-vme"
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
{
  "commandToExecute": "sudo apt-get update && apt-get install -y apache2 && sudo apt install jq && curl -H Metadata:true --noproxy \"*\" \"http://169.254.169.254/metadata/instance?api-version=2021-02-01\" | sudo tee myfile.txt && cat myfile.txt > /var/www/html/index.html"
}
SETTINGS
}