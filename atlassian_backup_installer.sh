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
### TAB set to 4 spaces

INSTALL_DIRECTORY="/opt/backup_scripts"

DIR=$(dirname $0)
CONFL_BCKP_SCRIPTNAME="atlassian_confluence_backup.sh"
JIRA_BCKP_SCRIPTNAME="atlassian_jira_backup.sh"


if [ ! -d ${INSTALL_DIRECTORY} ];then
    mkdir ${INSTALL_DIRECTORY}
    echo -ne "Install Directory: ${INSTALL_DIRECTORY} created!\n"
    exit 1
fi

#TODO REMOVE THIS LINE
echo "ACtual directory is ${DIR}"
##########

if [ ! -e ${DIR}/${CONFL_BCKP_SCRIPT_NAME} ] || [ ! -e "${DIR}/${HURA_BCKP_SCRIPT_NAME}" ];then
    echo -ne "${CONFL_BCKP_SCRIPTNAME} or ${JIRA_BCKP_SCRIPTNAME} doesnt exist int ${DIR}"
    exit 1
fi

write_config_file(){
    instance_type=${1}
    home_dir=${2}
    install_dir=${3}
    db_name=${4}
    db_username=${5}
    db_passwd=${6}

    if [ "${instance_type}" = "jira" ];then
        if [ -f ${INSTALL_DIRECTORY}/jira_backup.conf ];then
            echo -ne "Config file for JIRA backup already exist [ ${INSTALL_DIRECTORY}/jira_backup.conf ]\n"
            echo -ne "Do you want to rewrite it? [y|n] : \n" "\n"
            read rewrite_jira_config
            if [ "${rewrite_jira_config}" = "y" ];then
                cat << EOF > ${INSTALL_DIRECTORY}/jira_backup.conf
#Configuration file for back up Atlassian Jira Instance
jira_home_directory="$home_dir"
jira_install_directory="$install_dir"
jira_database_name="$db_name"
jira_database_username="$db_username"
jira_database_password="$db_passwd"
EOF
            else
                echo -ne "Exiting ...\n"
                exit 1
            fi
        else
            echo -ne "Writing configuration to ${INSTALL_DIRECTORY}/jira_backup.conf ! \n"
            cat << EOF > ${INSTALL_DIRECTORY}/jira_backup.conf
#Configuration file for back up Atlassian Jira Instance
jira_home_directory="$home_dir"
jira_install_directory="$install_dir"
jira_database_name="$db_name"
jira_database_username="$db_username"
jira_database_password="$db_passwd"
EOF
        fi
    # write configuration for confluence
    elif [ "${instance_type}" = "confluence" ];then
        if [ -f ${INSTALL_DIRECTORY}/confluence_backup.conf ];then
            echo -ne "Config file for Confluence backup already exist [ ${INSTALL_DIRECTORY}/confluence_backup.conf ]\n"
            echo -ne "Do you want to rewrite it? [y|n] : \n" "\n"
            read rewrite_confluence_config
            if [ "${rewrite_confluence_config}" = "y" ];then
                cat << EOF > ${INSTALL_DIRECTORY}/confluence_backup.conf
#Configuration file for back up Atlassian Confluence Instance
confluence_home_directory="$home_dir"
confluence_install_directory="$install_dir"
confluence_database_name="$db_name"
confluence_database_username="$db_username"
confluence_database_password="$db_passwd"
EOF
            else
                echo -ne "Exiting ...\n"
                exit 1
            fi
        else
            echo -ne "Writing configuration to ${INSTALL_DIRECTORY}/confluence_backup.conf ! \n"
            cat << EOF > ${INSTALL_DIRECTORY}/confluence_backup.conf
#Configuration file for back up Atlassian Confluence Instance
confluence_home_directory="$home_dir"
confluence_install_directory="$install_dir"
confluence_database_name="$db_name"
confluence_database_username="$db_username"
confluence_database_password="$db_passwd"
EOF
        fi
    fi

}

install_wiz_jira()    {
        echo -ne "Setting up backup plan for JIRA instance.\n"
        echo -ne "JIRA HOME directory [e.g. /var/atlassian/application-data/jira/]\n" "\n"
        read jira_home_directory
        if [ ! -d "${jira_home_directory}" ];then
            echo -ne "${jira_home_directory} does not exist !\n"
            exit 1
        fi
        echo -ne "JIRA INSTALL directory [e.g. /opt/atlassian/jira/]\n" "\n"
        read jira_install_directory
        if [ ! -d "${jira_install_directory}" ];then
            echo -ne "${jira_install_directory} does not exist !\m"
            exit 1
        fi
        echo -ne "JIRA Database Name: \n" "\n"
        read jira_db_name
        if [ -z "${jira_db_name}" ];then
            echo -ne "Wrong input for Jira Database Name!\n"
            exit 1
        fi
        echo -ne "JIRA Database username: \n" "\n"
        read jira_usr_name
        
        if [ -z "${jira_usr_name}" ];then
            echo -ne "Wrong input for Jira Database Username!\n"
            exit 1
        fi
        echo -ne "${jira_usr_name}'s DB password: \n" "\n"
        read -s jira_usr_pass
        if [ -z "${jira_usr_pass}" ];then
            echo -ne "Wrong input for Jira Database Password!\n"
            exit 1
        fi

        echo -ne "Preparing inputs ... \n" "\n"
        sleep 1
        echo -ne "################################################\n"
        echo -ne "Jira Home Directory :     ${jira_home_directory} \n"
        echo -ne "Jira Install Directory :  ${jira_install_directory} \n"
        echo -ne "Jira DB Name:             ${jira_db_name} \n"
        echo -ne "Jira DB User Name :       ${jira_usr_name} \n"
        echo -ne "Jira DB Password  :       ************** \n"
        echo -ne "################################################\n"
        echo -ne "Please confirm that informations above are correct [y/n]: \n" "\n"
        read confirm_jira_settings
        if [ "${confirm_jira_settings}" = "y" ];then
            #write configurat
            echo "Writing configuration"
            write_config_file "jira" ${jira_home_directory} ${jira_install_directory} ${jira_db_name} ${jira_usr_name} ${jira_usr_pass}
        elif [ "${confirm_jira_settings}" = "n" ];then
            exit 1
        fi
}

install_wiz_confluence()    {
        echo -ne "Setting up backup plan for CONFLUENCE instance.\n"
        echo -ne "CONFLUENCE HOME directory [e.g. /var/atlassian/application-data/confluence/]\n" "\n"
        read confluence_home_directory
        if [ ! -d "${confluence_home_directory}" ];then
            echo -ne "${confluence_home_directory} does not exist !\n"
            exit 1
        fi
        echo -ne "CONFLUENCE INSTALL directory [e.g. /opt/atlassian/confluence/]\n" "\n"
        read confluence_install_directory
        if [ ! -d "${confluence_install_directory}" ];then
            echo -ne "${confluence_install_directory} does not exist !\m"
            exit 1
        fi
        echo -ne "CONFLUENCE Database Name: \n" "\n"
        read confluence_db_name
        if [ -z "${confluence_db_name}" ];then
            echo -ne "Wrong input for Confluence Database Name!\n"
            exit 1
        fi
        echo -ne "CONFLUENCE Database username: \n" "\n"
        read confluence_usr_name
        
        if [ -z "${confluence_usr_name}" ];then
            echo -ne "Wrong input for Confluence Database Username!\n"
            exit 1
        fi
        echo -ne "${confluence_usr_name}'s DB password: \n" "\n"
        read -s confluence_usr_pass
        if [ -z "${confluence_usr_pass}" ];then
            echo -ne "Wrong input for Confluence Database Password!\n"
            exit 1
        fi

        echo -ne "Preparing inputs ... \n" "\n"
        sleep 1
        echo -ne "################################################\n"
        echo -ne "Confluence Home Directory :       ${confluence_home_directory} \n"
        echo -ne "Confluence Install Directory :    ${confluence_install_directory} \n"
        echo -ne "Confluence DB Name:               ${confluence_db_name} \n"
        echo -ne "Confluence DB User Name :         ${confluence_usr_name} \n"
        echo -ne "Confluence DB Password  :         ************** \n"
        echo -ne "################################################\n"
        echo -ne "Please confirm that informations above are correct [y/n]: \n" "\n"
        read confirm_confl_settings
        if [ "${confirm_confl_settings}" = "y" ];then
            #write configur
            echo "Writing configuration"
            write_config_file "confluence" ${confluence_home_directory} ${confluence_install_directory} ${confluence_db_name} ${confluence_usr_name} ${confluence_usr_pass}
        elif [ "${confirm_confl_settings}" = "n" ];then
            exit 1
        fi
}



echo -ne "Please choose options for backuping JIRA/CONFLUENCE instances\n"
echo -ne "Setup Backup for both, Confluence and JIRA instance [1],  Setup Backup only for JIRA or only for CONFLUENCE instance [2]. Choose 1-2 : " "\n"
read backup_option
sleep 1
echo -ne "You've choosed [$backup_option].\n"
sleep 1
if [ "${backup_option}" -eq "1" ];then  
    echo -ne "Preparing backup script for Confluence and JIRA instances ...\n"
    sleep 1
    install_wiz_jira
    install_wiz_confluence
elif [ "${backup_option}" -eq "2" ];then
    echo -ne "For what instance you want to setup backup plan? : \n" "\n"
    echo -ne "JIRA [1] , CONFLUENCE [2] : \n" "\n"
    read single_instance
    if [ "${single_instance}" -eq "1" ];then
        install_wiz_jira
    elif [ "${single_instance}" -eq "2" ];then
        echo -ne "Setting up backup plan for CONFLUENCE instance.\n"
        install_wiz_confluence
    else
        echo -ne "Wrong input! Exiting ..."
        sleep 1
        exit 1
    fi
else
    echo -ne "Wront input! Exiting ..."
    sleep 1
    exit 1
fi
        





