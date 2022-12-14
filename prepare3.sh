#!/usr/bin/bash
set -e
cat <<\EOF > env.sh
#!/usr/bin/bash
## ---------------------------- ##
## Instructions to fill out the needed information:
## 
## Locate your IBM_ENTITLEMENT_KEY (IBM entitlement key For Container Software) 
## Log in here using your IBM ID: 
## https://myibm.ibm.com/products-services/containerlibrary
## 
## Provide your name and email address for the 
## IBM User Data Service (UDS - formerly BAS).
##
## Provide your AppPoint license's Host ID. This is the value you supplied 
## when downloading the license.dat file from the License Key Center.
##
### --- Update this section --- ###
export IBM_ENTITLEMENT_KEY=
export UDS_CONTACT_EMAIL=
export UDS_CONTACT_FIRSTNAME=
export UDS_CONTACT_LASTNAME=
export SLS_LICENSE_ID=
### --------------------------- ###
export MAS_CONFIG_DIR=/scripts
export SLS_MONGODB_CFG_FILE=/scripts
export MAS_INSTANCE_ID=masdemo
export MAS_WORKSPACE_ID=masdev
export SLS_DOMAIN=svc.cluster.local
export SLS_LICENSE_FILE=/scripts/license.dat
EOF
cat <<\EOF > 0_core.sh
#!/usr/bin/bash
## To read env.sh file.
source $(dirname $(realpath ${0}))/env.sh
set -e
## Check.
if [[ -z "$IBM_ENTITLEMENT_KEY" ]] ; then
  echo "IBM container software's entitlement key must be defined."
  exit
fi
## Check.
FILE=/scripts/license.dat
if [[ ! -f "$FILE" ]] ; then
  echo "Place the AppPoint License file."
  exit
fi
set +e
export OCP_INGRESS=$(oc get ingress.config cluster -o jsonpath='{.spec.domain}')
export MAS_ANNOTATIONS=mas.ibm.com/operationalMode=nonproduction
ansible-playbook ibm.mas_devops.oneclick_core
EOF
cat <<\EOF > 1_separate_iot.sh
#!/usr/bin/bash
## To read env.sh file.
source $(dirname $(realpath ${0}))/env.sh
set -e
export DB2_INSTANCE_NAME=db2w-monitor
export DB2_DBNAME=BLUDB
export MAS_CONFIG_SCOPE=system
set +e
ansible-playbook ibm.mas_devops.oneclick_add_iot
set -e
oc project mas-masdemo-iot
oc get pods --field-selector 'status.phase=Failed' -o name | xargs oc delete
EOF
cat <<\EOF > 2_separate_monitor.sh
#!/usr/bin/bash
## To read env.sh file.
source $(dirname $(realpath ${0}))/env.sh
export DB2_INSTANCE_NAME=db2w-monitor
export DB2_DBNAME=BLUDB
export MAS_CONFIG_SCOPE=system
ansible-playbook ibm.mas_devops.oneclick_add_monitor
EOF
cat <<\EOF > 3_separate_manage.sh
#!/usr/bin/bash
## To read env.sh file
source $(dirname $(realpath ${0}))/env.sh
## Generate random password: openssl rand -base64 12
export DB2_LDAP_PASSWORD=
## Check.
if [[ -z "$DB2_LDAP_PASSWORD" ]] ; then
  echo "Generate and provide a password."
  exit
fi
export DB2_INSTANCE_NAME=db2w-manage
export DB2_DBNAME=BLUDB
export DB2_LDAP_USERNAME=maximo
export MAS_CONFIG_SCOPE=wsapp
export MAS_APPWS_JDBC_BINDING=workspace-application
export MAS_APP_ID=manage
export MAS_APPWS_COMPONENTS="base=latest,health=latest"
export MAS_APP_SETTINGS_DEMODATA=true
export MAS_APP_SETTINGS_PERSISTENT_VOLUMES_FLAG=true
export MAS_APP_SETTINGS_SERVER_BUNDLES_SIZE=jms
ansible-playbook ibm.mas_devops.oneclick_add_manage.yml
### Add PVC post-deploy config for Manage
ROLE_NAME=suite_manage_attachments_config ansible-playbook ibm.mas_devops.run_role
ROLE_NAME=suite_manage_bim_config ansible-playbook ibm.mas_devops.run_role
EOF
chmod +x *.sh
exit 0
