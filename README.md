# regmgmt
Central management of registry keys in a SharePoint server farm by PowerShell

Maintenance operations may require to apply a consistent change of registry keys on several servers in farm for the time of intervention. An example of such change may be disabling User Access Control (UAC) for the time of running Microsoft SharePoint Configuration Wizard, or command line utility psconfigui.exe. Among others, it’s required after the installation of SharePoint cumulative updates. After the intervention, this setting in the registry must be changed back. Every time when this change is being applied to a computer, the computer must restart. 

If the server farm has redundancy, we don’t want to restart all servers at once. After initiating the restart, the script will wait whether the server will become operational, and only then apply the change to the next server. The script has two checks for it. 

First, the script will wait until the restarted server will reply on cmdlet Test-Connection. 

Then, the script will wait until SharePoint services will be up and running. Two services are checked, SharePoint Timer and WWW Publishing. 

And, finally, the script checks on what server it is running. Changing the registry on the current server and its restart must go last, otherwise the script will “commit suicide” and will not complete it’s job. 
