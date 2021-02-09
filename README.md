## Test task for Cloudmore


 Open Weather Map metrics collector for Promethous and Grafana dashboard automatic deployment to MS Azure

Usage:

From terminal (MAC OS in my case):

terraform init 
terraform apply -auto-approve

Then check Public IP from Azure web. You can try az command also:

azure % az vm show --resource-group ResourceGroup --name Cloudmore -d --query myPublicIP -o tsv

Open Grafana from web browser:

http://AZUREpublicIP:3000

User: admin
Password: admin

# Dashboard is located Dashboards -> Manage -> Services -> Open Weather Map
