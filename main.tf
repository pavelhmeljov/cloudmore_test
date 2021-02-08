# Configure the Microsoft Azure Provider
provider "azurerm" {
    # The "feature" block is required for AzureRM provider 2.x.
    # If you're using version 1.x, the "features" block is not allowed.
        features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "mycloudmoregroup" {
    name     = "myResourceGroup"
    location = "Norway East"

    tags = {
        environment = "cloudmore Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "mycloudmorenetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "Norway East"
    resource_group_name = azurerm_resource_group.mycloudmoregroup.name

    tags = {
        environment = "cloudmore Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "mycloudmoresubnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.mycloudmoregroup.name
    virtual_network_name = azurerm_virtual_network.mycloudmorenetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "mycloudmorepublicip" {
    name                         = "myPublicIP"
    location                     = "Norway East"
    resource_group_name          = azurerm_resource_group.mycloudmoregroup.name
    allocation_method            = "Static"

    tags = {
        environment = "cloudmore Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "mycloudmorensg" {
    name                = "myNetworkSecurityGroup"
    location            = "Norway East"
    resource_group_name = azurerm_resource_group.mycloudmoregroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "prometheus"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "9090"
        source_address_prefix      = "*"
        destination_address_prefix = "VirtualNetwork"
    }

    security_rule {
        name                       = "grafana"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3000"
        source_address_prefix      = "*"
        destination_address_prefix = "VirtualNetwork"
    }


    tags = {
        environment = "cloudmore Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "mycloudmorenic" {
    name                      = "myNIC"
    location                  = "Norway East"
    resource_group_name       = azurerm_resource_group.mycloudmoregroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.mycloudmoresubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.mycloudmorepublicip.id
    }

    tags = {
        environment = "cloudmore Demo"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.mycloudmorenic.id
    network_security_group_id = azurerm_network_security_group.mycloudmorensg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.mycloudmoregroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.mycloudmoregroup.name
    location                    = "Norway East"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "cloudmore Demo"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = tls_private_key.example_ssh.private_key_pem }

# Create virtual machine
resource "azurerm_linux_virtual_machine" "mycloudmorevm" {
    name                  = "Cloudmore"
    location              = "Norway East"
    resource_group_name   = azurerm_resource_group.mycloudmoregroup.name
    network_interface_ids = [azurerm_network_interface.mycloudmorenic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "canonical"
        offer     = "0001-com-ubuntu-server-focal"
        sku       = "20_04-lts-gen2"
        version   = "latest"
    }

    computer_name  = "Cloudmore"
    admin_username = "admin"
    disable_password_authentication = false
    admin_password = "admin123"


    tags = {
        environment = "cloudmore Demo"
    }


    connection {
    host = "${azurerm_public_ip.mycloudmorepublicip.ip_address}"
    agent = false
    type = "ssh"
    user = "pavel"
    password = "Huj123"

    }

    provisioner "remote-exec" {
    inline = [
    "sudo apt update && sudo apt upgrade -y && sudo apt install docker* -y",
    "sudo docker pull prom/prometheus && sudo docker pull grafana/grafana",
    "sudo docker network create --subnet=10.0.0.0/24 cm-network",
    "sudo docker run --net cm-network --ip 10.0.0.2 -d -p 3000:3000 grafana/grafana",
    "sudo docker run --net cm-network --ip 10.0.0.3 -d -p 9090:9090 prom/prometheus"
    ]



}
}
