
#!/bin/bash


#Email information
send_mail=true
from_email_address="cassadm@searshc.com"
to_email_address="ecom_nosql@searshc.com"

#number of attempts information
max_attempts=3
max_attempt_file_path=/opt/cassandra/bin/attempts
interval=5

#Log information
export log_folder_path=/opt/cassandra/bin/restart_logs
log=`date +%d_%m_%Y`
logname="restart_"$log".log"
log_path=$log_folder_path"/"$logname
host=`hostname`

#create the temp directories
mkdir -p $log_folder_path
mkdir -p $max_attempt_file_path

#export ADMINS="NoSQLDBA@searshc.com"
export ADMINS="Ajith.Shetty@searshc.com"

send_alert() {
    /opt/recon/bin/send-recon-event eventType=error source=simple severity=critical server=`hostname` summary='OPS-1050 Cassandra Node found off-line\! Please page NoSQL on-call\!' +email="$ADMINS" >/dev/null
}



#cassandra_id=$(ps -ef | grep cassandra | grep -v grep | grep -v 'startCassandra[.]sh' | awk '{ print $2 }')

#cassandra_id=$(ps -ef | grep 'cassandra*' | grep -v grep | grep -v 'startCassandra[.]sh' | grep -v 'cqlsh*'|awk '{ print $2 }')
cassandra_id=$(ps -ef | grep 'org.apache.cassandra.service.CassandraDaemon*' | grep -v grep | grep -v 'startCassandra[.]sh' | grep -v 'cqlsh*'|awk '{ print $2 }')

cassandra_version=""

if [ -n "$cassandra_id" ]; then
   cassandra_version=`ps -ef |grep apache-cassandra|grep -v grep | grep -v 'startCassandra[.]sh' | grep -v 'cqlsh*'|egrep -o "*/apache-cassandra-*([0-9]{1,}\.)+[0-9]{1,}"|cut -c2- |awk 'NR==1{print $1}'`
   echo "`date` INFO: Running Cassandra Version: $cassandra_version"
else
   cassandra_version=`find /opt/cassandra/ -type f -name 'apache-cassandra*' -printf '%h\n' | sort  |egrep -o "*/apache-cassandra-*([0-9]{1,}\.)+[0-9]{1,}"|cut -c2- |awk 'NR==1{print $1}'`
   if [ -z "$cassandra_version" ]; then
      echo "`date` ERROR: No apache-cassandra binary present in the path"
      exit
   else
      echo "`date` ERROR: Cassandra is not running currently. Latest binary version present: $cassandra_version"
   fi
fi




export cassandra_bin_path=/opt/cassandra/instance/bin
export cassandra_conf_path=/opt/cassandra/instance/conf

log=`date +%d_%m_%Y`
logname="stop_"$log".log"
mkdir -p $log_folder_path
log_path=$log_folder_path"/"$logname
host=`hostname`

process=cassandra

if [ -t 1 ] ; then
        type="manual"
   #echo "Not from cron"  #since FD 1 (stdout) is open
else
        type="cron"
   #echo "From cron"
fi
#-------------------------------
progress_bar()
{

count=0
total=$1
pstr="[=======================================================================]"

while [ $count -lt $total ]; do
  sleep 1 # this is work
  count=$(( $count + 1 ))
  pd=$(( $count * 73 / $total ))
  printf "\r%3d.%1d%% %.${pd}s" $(( $count * 100 / $total )) $(( ($count * 1000 / $total) % 10 )) $pstr
done

}

#-------------------------------
cassandra_counter=0

while true; do

        #ps cax | grep cassandra > /dev/null
        #process_id=$(ps xu | grep $process | grep -v grep | awk '{ print $2 }')
        process_id=$(ps -ef | grep $process | grep -v grep | awk '{ print $2 }')
         echo""
         echo "`date` INFO: $process process id: $process_id"
        #if [ $process_id -ne 0 ]; then
        if [ -z "$process_id" ]; then
          echo "`date` INFO: $process is not running"


        elif [[ "$cassandra_counter" -eq "$max_attempts" ]]; then
           echo -e "Failed to stop $process in the host $host after $max_attempts attempts \n \nPlease check logs in the path for any error: $log_path" | mailx -s "STOP FAILED: $process HOST:$host" -r $from_email_address  $to_email_address


        else
        #echo "running "
          if [[ "$send_mail" = true && "$process" == "cassandra" ]] ; then

          echo -e "Stopping cassandra \n Host: $host \n Attempt: `expr ${cassandra_counter} + 1`(out of $max_attempts) \n After $max_attempts attempts $process will not try to stop \n Date Time: `date` \n \n Please check logs in the path for any error: $log_path" | mailx -s "STOP apache-cassandra HOST:$host" -r $from_email_address  $to_email_address
          fi
          if [ "$type" = "cron" ]; then
                echo "`date`ERROR: $process Process is running." >> $log_path
                echo "`date`:INFO: Stopping $process. Please wait...." >> $log_path
          else
                echo "`date`ERROR: $process Process is running."
                echo "`date`:INFO: Stopping $process. Please wait...."
          fi
          if [[ "$process" = "cassandra"  &&   "$cassandra_counter" -lt "$max_attempts" ]]; then
          cassandra_counter=`expr $cassandra_counter + 1`
          kill -9 $process_id >> $log_path
          fi
          echo "`date`ERROR: Waiting for $interval seconds..."
          #sleep $interval
          progress_bar $interval
          process_id=$(ps xu | grep $process | grep -v grep | awk '{ print $2 }')
          continue
        fi
        break
done
if [ "$type" = "manual" ]; then
echo "`date` INFO: Please check logs in the path: $log_path"
fi

