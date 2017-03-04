# Backup script for Atlassian Jira and Atlassian Confluence

scripts for backuping whole installation including MySQL database of JIRA and/or CONFLUENCE instance

## Getting Started
These instructions will help you to set daily backups using cron jobs.

### Prerequisites

For installation you have to know some informations about the running JIRA/CONFLUENCE instance for what you want to set up daily backups.

```
Name of Project for what is Confluence/Jira installed (important in case you have multiple Jira or Confluence instances on same host)
Confluence/Jira HOME directory (e.g. /var/atlassian/application-data/jira)
Confluence/Jira INSTALL directory (e.g. /opt/atlassian/jira)
Confluence/Jira Database name (e.g. jiradb)
Confluence/Jira Database user that has at least read permissions to Jira/Confluence Database.
Confluence/Jira password for Database user that has at least read permissions to Jira/Confluence Database.
```

### Installing

Clone the project
```
git clone https://github.com/kimkil94/JIRA-CONFLUENCE-BACKUP.git
```
Change directory
```
cd JIRA-CONFLUENCE-BACKUP/
```
Start the installer (under the root or with sudo)

```
# ./atlassian_backup_installer.sh
```

Choose one of the option, if you want to set backups for both instance (Jira and Confluence) choose [1] , for only Jira or Confluence backup choose [2]
```
Please choose options for backuping JIRA/CONFLUENCE instances
Setup Backup for both, Confluence and JIRA instance [1],  Setup Backup only for JIRA or only for CONFLUENCE instance [2]. Choose 1-2 : 
```

Write name of your Project [you can call it whatever you want]
```
Project Name of Jira/Confluence Instance: 
```
Set Jira/Confluence HOME directory  (for JIRA HOME check <jira-install>/atlassian-jira/WEB-INF/classes/jira-application.properties),
```
JIRA/CONFLUENCE HOME directory [e.g. /var/atlassian/application-data/jira(confluence)/]
```
Set Jira/Confluence INSTALL directory 
```
JIRA/CONFLUENCE INSTALL directory [e.g. /opt/atlassian/jira[confluence]/]
```

Set JIRA/CONFLUENCE Database name 
```
JIRA/CONFLUENCE Database Name: 
```

Set JIRA/CONFLUENCE DB username that has at least read access to database.
```
JIRA Database username: 
```
Use password for your Database user. (in this case it's "jirauser")
```
jirauser's password: 
```
Confirm settings
```
################################################
Jira Project Name:        [TestProject]
Jira Home Directory :     /var/atlassian/application-data/jira/ 
Jira Install Directory :  /opt/atlassian/jira/ 
Jira DB Name:             jiradb 
Jira DB User Name :       jirauser
Jira DB Password  :       ************** 
################################################
Please confirm that informations above are correct [y/n]:
```
Afterthat configuration files will be created in directory /opt/backup_scripts/, and cronjob files will be created in /etc/cron.d/ . Both jobs are set to 00:30 every day.

