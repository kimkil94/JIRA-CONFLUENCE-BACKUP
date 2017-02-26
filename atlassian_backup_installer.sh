#!/bin/bash

###!************************************************************************************************!###
### Description: Backup Database,Confluence Home and Confluence Install directory
### Following arguments need to be passed: 
###  --database DB_NAME --username USERNAME --password PASSWORD --confluence-home-dir CONFLUENCE_HOME_DIR --confluence-install-dir CONFLUENCE_INSTALL_DIR 
###
###      --database                     specify name of database that will be dumped (SQL Database)
###      --username                     username for access to database
###      --password                     password for DB user
###      --confluence-home-dir                  Jira Home Directory
###      --confluence-install-dir               Jira Install Directory
###
### ----------------------------------------------------------------
### Written by: Kimkil 2017
### P.S. Feel free to change anything that will improve this script :-)
###!************************************************************************************************!###
###
###

INSTALL_DIRECTORY="/opt/backup_scripts"

DIR=$(dirname $0)
CONFL_BCKP_SCRIPTNAME="atlassian_confluence_backup.sh"
JIRA_BCKP_SCRIPTNAME="atlassian_jira_backup.sh"


if [ ! -d ${INSTALL_DIRECTORY} ];then
    mkdir ${INSTALL_DIRECTORY}
    echo -ne "Install Directory: ${INSTALL_DIRECTORY} created!\n"
    exit 1
fi

echo "ACtual directory is ${DIR}"

if [ ! -e ${DIR}/${CONFL_BCKP_SCRIPT_NAME} ] || [ ! -e "${DIR}/${HURA_BCKP_SCRIPT_NAME}" ];then
    echo -ne "${CONFL_BCKP_SCRIPTNAME} or ${JIRA_BCKP_SCRIPTNAME} doesnt exist int ${DIR}"
    exit 1
fi




