#!/bin/bash

#Backup jira and confluence
#


#Variables definition

##-------Global settings---------------------------#
BACKUPDIR="/home/backup"
MYSQLDUMPBASEFILENAME=$(date +%F)"_mysql_dump"
PROJECT_NAME="TEST_PROJECT"
##-------------------------------------------------#
##-----Logging functions---------------------------#

readonly SCRIPT_NAME=$(basename $0)

#log only stderr to syslog
errlogmsg()
{
	if [ -n "$1" ]; then
      		IN="$1"
  	else
   		read IN # This reads a string from stdin and stores it in a variable called IN
  	fi
	
	if [[ -n "${IN// }" ]]; then
  		logger -t $SCRIPT_NAME "ERROR : $IN"
	fi
	
	IN=""
}

#log only stdout to syslog
logmsg()
{
	if [ -n "$1" ]; then
      		IN="$1"
  	else
        	read IN # This reads a string from stdin and stores it in a variable called IN
  	fi
  	logger -t $SCRIPT_NAME $IN
}

print_usage(){
	echo "Usage $0 --database DB_NAME --username USERNAME --password PASSWORD --jira-home-dir JIRA_HOME_DIR --jira-install-dir JIRA_INSTALL_DIR"
}

##--------------------------------------------------#

##----------GetOpt----------------------------------#

#check if at least one argument has been passed
if [ $# -eq 0 ]; then
        echo "No argument passed!"
        print_usage
	exit 1
fi


#get all arguments using getopt
TEMP=`getopt -o ab:c:: --long database:,username:,password:,jira-home-dir:,jira-install-dir: \
     -n 'example.bash' -- "$@"`

#terminate script if getopt return non zero
if [ $? != 0 ] || [ "$1" != "--database" ] || [ "$3" != "--username" ] || [ "$5" != "--password" ] || [ "$7" != "--jira-home-dir" ] || [ "$9" != "--jira-install-dir" ]; then 
	echo "Terminating..." >&2 | errlogmsg 
	print_usage
	exit 1
 fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

#get and set general vars
while true ; do
        case "$1" in
                #pass name of database
                --database)  
                        DBNAME=$2 
                        shift 2 ;;
                #pass username for accessing database
                --username) 
                        DBUSERNAME=$2 
                        shift 2 ;;
                #pass password for username
                --password)  
                        DBPASSWORD=$2 
                        shift 2 ;;
                --jira-home-dir)  
                        JIRAHOME=$2 
                        shift 2 ;;
                 --jira-install-dir)  
                        JIRAINSTALLDIR=$2 
                        shift 2 ;;
 
                --) shift ; break ;;
                *) echo "Internal error!" ; exit 1 ;;
        esac
done

##--------------------------------------------------#

##--------JIRA/CONFLUENCE SETTINGS---------#
ATLASSIAN_BACKUP_FILE_NAME=${PROJECT_NAME}_atlassian-backup
ATLASSIAN_BACKUP_DIR=${BACKUPDIR}"/"${ATLASSIAN_BACKUP_FILE_NAME}

#Confluence
#CONF_DB_USER=""
#CONF_DB_PASSWD=""
#CONF_DB_NAME=""

#CONF_HOME=""
#MYSQLDUMP_EXTENSION_CONFL=$MYSQLDUMPBASEFILENAME"_confluence.sql"

## -- Jira settings -- ##

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
COMPRESSED_FILE_NAME=${ATLASSIAN_BACKUP_DIR}"/"$(date +%F)"_"${ATLASSIAN_BACKUP_FILE_NAME}.tar
STAT_FILE="/var/stat_backup_file_${PROJECT_NAME}" #stat file used for storing size (in MB) of latest backup archive file /COMPRESSED_FILENAME/
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

## Backup  Jira and Confluence Instance ##
echo "Starting backuping ${PROJECT_NAME} JIRA application data." | logmsg

# Lock database tables to avoid inconsistency
(
	  # Write-Lock database, db is still readable, but not writable
	  echo "FLUSH TABLES WITH READ LOCK;" 
  
) | mysql --user=${JIRADBUSER} --password=${JIRADBPASSWD} 2>&1 >/dev/null | errlogmsg

# Dump jira database into file
JIRA_MYSQL_DUMP_FILE_NAME=${ATLASSIAN_BACKUP_DIR}"/"${MYSQLDUMP_EXTENSION_JIRA}

mysqldump -u ${JIRADBUSER} -p${JIRADBPASSWD} ${JIRADBNAME} --max_allowed_packet=512M  > ${JIRA_MYSQL_DUMP_FILE_NAME} 2>&1 >/dev/null | errlogmsg

# Create backup from JIRA home directory, Jira database dump files
tar rf  ${COMPRESSED_FILE_NAME} ${JIRA_INSTALL_DIR} ${JIRA_HOME} ${JIRA_MYSQL_DUMP_FILE_NAME} 2>&1 >/dev/null | errlogmsg
  
# Remove sql database dumps, because tar file contains them
rm  ${ATLASSIAN_BACKUP_DIR}/*.sql > /dev/null 2>&1

# Unlock database
( 
  echo "UNLOCK TABLES;"
) | mysql --user=${JIRADBUSER} --password=${JIRADBPASSWD} 2>&1 >/dev/null | errlogmsg

# Compress data with gzip
/bin/gzip -f ${COMPRESSED_FILE_NAME} 2>&1 >/dev/null | errlogmsg

# be sure that new compressed file is not empty
if [ -s ${COMPRESSED_FILE_NAME}.gz ];then
	echo "Backup file: ${COMPRESSED_FILE_NAME} created successfully." | logmsg
	# if it is first run(NOSTAT==1), get size of archive file and write it to stat file.
	if [ $NOSTAT -eq "1" ]; then
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


