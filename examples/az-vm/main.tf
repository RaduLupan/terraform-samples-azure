provider "azurerm" {
    version = "2.0.0"
    subscription_id = var.subscriptionID
    features {}
}

# Use locals block for simple constants or calculated variables https://www.terraform.io/docs/configuration/locals.html
locals {
    project = "terraform-samples"
    environment = "dev"
}

resource "azurerm_network_interface" "nic01" {
  name                = "nic-${var.serverName}"
  location            = var.location
  resource_group_name = var.resourceGroup

  ip_configuration {
    name                          = "IPconfiguration1"
    subnet_id                     = var.subnetId
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip01.id
  }
}

resource "azurerm_virtual_machine" "vm01" {
  name                  = var.serverName
  location              = var.location
  resource_group_name   = var.resourceGroup
  network_interface_ids = [azurerm_network_interface.nic01.id]
  vm_size               = "Standard_B1ms"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "os-disk-${var.serverName}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = var.serverName
    admin_username = "azureadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "${local.environment}"
    project = "${local.project}"
  }
}

resource "azurerm_virtual_machine_extension" "custom_script" {
  name                 = var.serverName
  virtual_machine_id   = azurerm_virtual_machine.vm01.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  ## Install Azure CLI on Ubuntu as per https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest
  settings = <<SETTINGS
    {
        "commandToExecute": "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    }
SETTINGS
}

resource "azurerm_public_ip" "pip01" {
  name                = "PublicIp1"
  resource_group_name = var.resourceGroup
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    environment = "${local.environment}"
    project = "${local.project}"
  }
}