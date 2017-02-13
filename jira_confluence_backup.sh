#!/bin/bash

#Backup jira and confluence

#Variables definition

##-------Global settings---------------------------#
BACKUPDIR="/home/backup"
MYSQLDUMPBASEFILENAME=$(date +%F)"_mysql_dump"
PROJECT_NAME="TEST_PROJECT"
##-------------------------------------------------#
##-----Logging functions---------------------------#

readonly SCRIPT_NAME=$(basename $0)

errlogmsg()
{
  if [ -n "$1" ]
  then
      IN="$1"
  else
      read IN # This reads a string from stdin and stores it in a variable called IN
  fi
if [[ -n "${IN// }" ]]; then
  logger -t $SCRIPT_NAME "ERROR : $IN"
fi
IN=""
}

logmsg()
{
  if [ -n "$1" ]
  then
      IN="$1"
  else
      read IN # This reads a string from stdin and stores it in a variable called IN
  fi
  logger -t $SCRIPT_NAME $IN
}

##--------------------------------------------------#


##----------GetOpt----------------------------------#
if [ $# -eq 0 ]; then
        echo "No argument passed!"
        echo "Usage $0 --database DB_NAME --username USERNAME --password PASSWORD"
        exit 1
fi



TEMP=`getopt -o ab:c:: --long database:,username:,password: \
     -n 'example.bash' -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

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
                --) shift ; break ;;
                *) echo "Internal error!" ; exit 1 ;;
        esac
done

##--------------------------------------------------#

##--------JIRA/CONFLUENCE SETTINGS---------#
ATLASSIAN_BACKUP_FILE_NAME=${PROJECT_NAME}_atlassian-backup
ATLASSIAN_BACKUP_DIR=$BACKUPDIR"/"$ATLASSIAN_BACKUP_FILE_NAME

#Confluence
#CONF_DB_USER=""
#CONF_DB_PASSWD=""
#CONF_DB_NAME=""

#CONF_HOME=""
#MYSQLDUMP_EXTENSION_CONFL=$MYSQLDUMPBASEFILENAME"_confluence.sql"

#Jira settings
if [ ! -z $DBUSERNAME ] || [ ! -z $DBPASSWORD ] || [ ! -z $DBNAME ];then
JIRADBUSER="$DBUSERNAME"
JIRADBPASSWD="$DBPASSWORD"
JIRADBNAME="$DBNAME"
else
	echo "[ERROR]: Database credentials were not set properly! please check arguments! " | errlogmsg
fi
JIRA_HOME="/var/atlassian/application-data/jira/"
JIRA_INSTALL_DIR="/opt/atlassian/jira/"

MYSQLDUMP_EXTENSION_JIRA=$MYSQLDUMPBASEFILENAME"_"$PROJECT_NAME"_jira.sql"

#Final compressed file name
COMPRESSED_FILE_NAME=${ATLASSIAN_BACKUP_DIR}"/"$(date +%F)"_"${ATLASSIAN_BACKUP_FILE_NAME}.tar
STAT_FILE="/var/stat_backup_file_${PROJECT_NAME}"
NOSTAT="0"
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

if [ ! -e $STAT_FILE ]; then
   touch $STAT_FILE
   NOSTAT="1"
fi

## Backup  Jira and Confluence Instance ##


echo "Starting backuping ${PROJECT_NAME} JIRA application data." | logmsg

# Jira backup
(
	  # Write-Lock database, db is still readable, but not writable
	  echo "FLUSH TABLES WITH READ LOCK;" 
  
) | mysql --user=${JIRADBUSER} --password=${JIRADBPASSWD} 2>&1 >/dev/null | errlogmsg

   # Dump jira database into file
  JIRA_MYSQL_DUMP_FILE_NAME=${ATLASSIAN_BACKUP_DIR}"/"${MYSQLDUMP_EXTENSION_JIRA}

  mysqldump -u ${JIRADBUSER} -p${JIRADBPASSWD} ${JIRADBNAME} --max_allowed_packet=512M  > $JIRA_MYSQL_DUMP_FILE_NAME 2>&1 >/dev/null | errlogmsg

  # Create backup from JIRA home directory, Jira database dump files
  tar rf  ${COMPRESSED_FILE_NAME} ${JIRA_INSTALL_DIR} ${JIRA_HOME} ${JIRA_MYSQL_DUMP_FILE_NAME} 2>&1 >/dev/null | errlogmsg
  
  # Remove sql database dumps, because tar file contains them
  rm  ${ATLASSIAN_BACKUP_DIR}/*.sql > /dev/null 2>&1

  # Unlock database
( 
  echo "UNLOCK TABLES;"
) | mysql --user=${JIRADBUSER} --password=${JIRADBPASSWD} 2>&1 >/dev/null | errlogmsg

# Confluence backup
#(
#  # Write-Lock database, db is still readable, but not writable
#  echo "FLUSH TABLES WITH READ LOCK;"
#
#  # Dump _conflunence database into file
#  CONFL_MYSQL_DUMP_FILE_NAME=$ATLASSIAN_BACKUP_DIR/$MYSQLDUMP_EXTENSION_CONFL
#  mysqldump -u $CONF_DB_USER -p$CONF_DB_PASSWD $CONF_DB_NAME --max_allowed_packet=512M > $CONFL_MYSQL_DUMP_FILE_NAME
#
#  # Create backup from JIRA home directory, CONFLUENCE home directory, and Confluence and Jira database dump files
#  tar rf  ${COMPRESSED_FILE_NAME} ${CONF_HOME} ${CONFL_MYSQL_DUMP_FILE_NAME}
#
#  # Remove sql database dumps, because tar file contains them
#  rm  ${ATLASSIAN_BACKUP_DIR}/*.sql
#
#  # Unlock database
#  echo "UNLOCK TABLES;"
#
#) | mysql --user=${CONF_DB_USER} --password=${CONF_DB_PASSWD}


# Compress data with gzip
/bin/gzip -f $COMPRESSED_FILE_NAME 2>&1 >/dev/null | errlogmsg

if [ -s ${COMPRESSED_FILE_NAME}.gz ];then
	echo "Backup file: $COMPRESSED_FILE_NAME created successfully." | logmsg
	
	if [ $NOSTAT -eq "1" ]; then
		du -m ${COMPRESSED_FILE_NAME}.gz | awk '{print $1}' > $STAT_FILE
	fi
	if [ $NOSTAT -eq "0" ]; then
		LAST_SIZE=$(cat $STAT_FILE)
		ACTUAL_SIZE=$(du -m  ${COMPRESSED_FILE_NAME}.gz | awk '{print $1}')
		
		if [[ "$ACTUAL_SIZE" -gt "$LAST_SIZE" ]] || [[ "$ACTUAL_SIZE" -eq "$LAST_SIZE"  ]]; then
			echo "[INF]Backup of $PROJECT_NAME jira instance done successfully." |logmsg
			echo "[INF]Compressed archive file has $ACTUAL_SIZE MB" | logmsg
			exit 0
		else
			echo "[ERR]: Backup of $PROJECT_NAME jira instance was unsuccessful!"  | errlogmsg
			echo "[INF]: Compressed archive file has only $ACTUAL_SIZE MB!" | errlogmsg
			exit 1
		fi
	fi
else
	echo "[ERR]: Backup file $COMPRESSED_FILE_NAME was not created!" | errlogmsg
	exit 1
fi


