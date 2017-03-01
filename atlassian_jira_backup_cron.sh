#!/bin/bash

###!************************************************************************************************!###
### Description: Backup Database,JIRA Home and JIRA Install directory
### Used by cron JOB
### ----------------------------------------------------------------
### Written by: Kimkil 2017
### P.S. Feel free to change anything that will improve this script :-)
###!************************************************************************************************!###



#Variables definition

##-------Global settings---------------------------#
BACKUPDIR="/home/backup"
MYSQLDUMPBASEFILENAME=$(date +%F)"_mysql_dump"
PROJECT_NAME="${1}"
##-------------------------------------------------#
##-----Logging functions---------------------------#

readonly SCRIPT_NAME=$(basename "$0")

#log only stderr to syslog
errlogmsg()
{
	if [ -n "${1}" ]; then
      		IN="${1}"
  	else
   		read -r IN # This reads a string from stdin and stores it in a variable called IN
  	fi
	
	if [[ -n "${IN// }" ]]; then
  		logger -t ${SCRIPT_NAME} "ERROR : ${IN}"
	fi
	
	IN=""
}

#log only stdout to syslog
logmsg()
{
	if [ -n "${1}" ]; then
      		IN="${1}"
  	else
        	read -r IN # This reads a string from stdin and stores it in a variable called IN
  	fi
  	logger -t "${SCRIPT_NAME}" "${IN}"
}

print_usage(){
	echo "Usage ${0} --database DB_NAME --username USERNAME --password PASSWORD --jira-home-dir JIRA_HOME_DIR --jira-install-dir JIRA_INSTALL_DIR"
}

##--------------------------------------------------#
##--------JIRA/CONFLUENCE SETTINGS---------#
ATLASSIAN_BACKUP_FILE_NAME=${PROJECT_NAME}_atlassian-backup
ATLASSIAN_BACKUP_DIR=${BACKUPDIR}"/"${ATLASSIAN_BACKUP_FILE_NAME}



##--------CONFLUENCE/CONFLUENCE SETTINGS---------#
JIRA_CONF="/opt/backup_scripts/${PROJECT_NAME}_jira_backup.conf"

## -- Jira settings -- ##
source ${JIRA_CONF}

JIRAHOME=${jira_home_directory}
JIRAINSTALLDIR=${jira_install_directory}
DBUSERNAME=${jira_database_username}
DBNAME=${jira_database_name}
DBPASSWORD=${jira_database_password}

# make sure that any of the database connector variables are note empty 
if [ ! -z ${DBUSERNAME} ] || [ ! -z ${DBPASSWORD} ] || [ ! -z ${DBNAME} ]; then
	JIRADBUSER=${DBUSERNAME}
	JIRADBPASSWD=${DBPASSWORD}
	JIRADBNAME=${DBNAME}
else
	echo "[ERROR]: Database credentials were not set properly! please check arguments! " | errlogmsg
fi

# make sure that directory variables are not not
if [ ! -z ${JIRAHOME} ] || [ ! -z ${JIRAINSTALLDIR} ]; then
	JIRA_HOME=${JIRAHOME}
	JIRA_INSTALL_DIR=${JIRAINSTALLDIR}
# make sure that JIRA home directory exist
elif [ ! -d ${JIRAHOME} ]; then 
	echo "[ERROR]: Jira Home Directory: ${JIRAHOME} does not exist!" | errlogmsg
	echo "[INF]: exiting 1" | errlogmsg
	exit 1
# make sure that JIRA install directory exist
elif [ -d ${JIRAINSTALLDIR} ]; then 
	echo "[ERROR]: Jira Install Directory: ${JIRAINSTALLDIR} does not exist!" | errlogmsg
	echo "[INF]: exiting 1" | errlogmsg
	exit 1
else
	echo "[ERROR]: Jira Home Directory or Jira Install Directory has not been specified: Quiting! " | errlogmsg
	exit 1
fi

# definition of absolut path to SQL dump file
MYSQLDUMP_EXTENSION_JIRA=${MYSQLDUMPBASEFILENAME}"_"${PROJECT_NAME}"_jira.sql"

#Final compressed file name
COMPRESSED_FILE_NAME=${ATLASSIAN_BACKUP_DIR}"/"$(date +%F)"_"${ATLASSIAN_BACKUP_FILE_NAME}_jira.tar
STAT_FILE="/var/stat_backup_file_${PROJECT_NAME}_jira" #stat file used for storing size (in MB) of latest backup archive file /COMPRESSED_FILENAME/
NOSTAT="0" #zeroing variable
##-------------------------------------------------#

##------Start of backup script--------------------##

#TODO: do not remove if exists
# If default backup directory does not exists create it
if [ ! -d ${BACKUPDIR} ]; then
	mkdir ${BACKUPDIR}
fi

if [ ! -e ${ATLASSIAN_BACKUP_DIR}  ]; then
	mkdir ${ATLASSIAN_BACKUP_DIR}
fi

# if stat file does not exist create it
if [ ! -e ${STAT_FILE} ]; then
	touch ${STAT_FILE}
	NOSTAT="1" # set variable to know that stat_file does not contain any value now -> its done usually in first run of script, initial backup
fi

# remove some partially archived files if exist
if [ -e ${COMPRESSED_FILE_NAME} ]; then
	rm  ${COMPRESSED_FILE_NAME}
	echo "[INF]: Removing old not complete backup tar file ( ${COMPRESSED_FILE_NAME} )" | logmsg
fi

## Backup  Jira and Confluence Instance ##
echo "Starting backuping ${PROJECT_NAME} JIRA application data." | logmsg

# Lock database tables to avoid inconsistency
(
	  # Write-Lock database, db is still readable, but not writable
	  echo "FLUSH TABLES WITH READ LOCK;" 
  
) | mysql --user=${JIRADBUSER} --password=${JIRADBPASSWD} 2>&1 >/dev/null | grep -vi warning | errlogmsg

# Dump jira database into file
JIRA_MYSQL_DUMP_FILE_NAME=${ATLASSIAN_BACKUP_DIR}"/"${MYSQLDUMP_EXTENSION_JIRA}

mysqldump -u ${JIRADBUSER} -p${JIRADBPASSWD} ${JIRADBNAME} --max_allowed_packet=512M  > ${JIRA_MYSQL_DUMP_FILE_NAME} 2>&1 >/dev/null | errlogmsg

# Create backup from JIRA home directory, Jira database dump files
tar rf  ${COMPRESSED_FILE_NAME} ${JIRA_INSTALL_DIR} ${JIRA_HOME} ${JIRA_MYSQL_DUMP_FILE_NAME} 2>&1 >/dev/null | grep -vi "Removing leading" | errlogmsg
  
# Remove sql database dumps, because tar file contains them
rm  ${ATLASSIAN_BACKUP_DIR}/*.sql > /dev/null 2>&1

# Unlock database
( 
  echo "UNLOCK TABLES;"
) | mysql --user=${JIRADBUSER} --password=${JIRADBPASSWD} 2>&1 >/dev/null | grep -vi warning | errlogmsg

# Compress data with gzip
/bin/gzip -f ${COMPRESSED_FILE_NAME} 2>&1 >/dev/null | errlogmsg

# be sure that new compressed file is not empty
if [ -s ${COMPRESSED_FILE_NAME}.gz ];then
	echo "Backup file: ${COMPRESSED_FILE_NAME} created successfully." | logmsg
	# if it is first run(NOSTAT==1), get size of archive file and write it to stat file.
	if [ ${NOSTAT} -eq "1" ]; then
		du -m ${COMPRESSED_FILE_NAME}.gz | awk '{print $1}' > ${STAT_FILE}
	fi
	# if it is NOT first run
	if [ ${NOSTAT} -eq "0" ]; then
		LAST_SIZE=$(cat ${STAT_FILE}) # get the size of previous backup file (using stat file)
		ACTUAL_SIZE=$(du -m  ${COMPRESSED_FILE_NAME}.gz | awk '{print $1}') # get the size of current backup file
		# if current backup file has same or bigger size as a previous backup file -> it is OK -> log - > exit 0
		if [[ "${ACTUAL_SIZE}" -gt "${LAST_SIZE}" ]] || [[ "${ACTUAL_SIZE}" -eq "${LAST_SIZE}"  ]]; then
			echo "[INF]Backup of ${PROJECT_NAME} jira instance done successfully." |logmsg
			echo "[INF]Compressed archive file has ${ACTUAL_SIZE} MB" | logmsg
			echo "${ACTUAL_SIZE}" > ${STAT_FILE}
			exit 0
		else  # if current backup file is smaller than previous backup file -> not OK -> errlog -> exit 1
			echo "[ERR]: Backup of ${PROJECT_NAME} jira instance was unsuccessful!"  | errlogmsg
			echo "[INF]: Compressed archive file has only ${ACTUAL_SIZE} MB!" | errlogmsg
			exit 1
		fi
	fi
else # if compressed backup file is empty -> errlog -> exit 1
	echo "[ERR]: Backup file ${COMPRESSED_FILE_NAME} was not created!" | errlogmsg
	exit 1
fi


