/*test*/

provider "azurerm" {
   features {}
}

terraform {
  backend "azurerm" {
    resource_group_name   = "Terraform"
    storage_account_name  = "terraformtfstate01"
    container_name        = "tfstate01"
    key                   = "tfstate"
  }
}

/*resource "azurerm_resource_group" "Terraform" {
  name     = "Terraform"
  location = "francecentral"
} */

resource "azurerm_resource_group" "rg" {
  name     = "tf-ref-${var.environment}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "webserver" {
  name                = "webservervnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "webserversubnet" {
  name                 = "webserversubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.webserver.name
  address_prefix       = "10.1.0.0/24"

}


resource "azurerm_availability_set" "aset" {
  name                = "example-aset"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

}

resource "azurerm_public_ip" "publicip" {
  name                = "publiciptestterraform01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"

}

resource "azurerm_network_interface" "main" {
  name                = "${var.VM}-${format("%03d",count.index)}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  count = var.number
  

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.webserversubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = count.index == 1 ? azurerm_public_ip.publicip.id : null
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.webserversubnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.VM}-${format("%03d",count.index)}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.main[count.index].id]
  vm_size               = "Standard_DS1_v2"
  availability_set_id = azurerm_availability_set.aset.id
  count = var.number

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name = "hdd-${format("%02d",count.index)}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "staging"
  }
}
