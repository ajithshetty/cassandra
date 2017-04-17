#!/bin/bash

#Email information
send_mail=true
from_email_address="from_add@some_example.com"
to_email_address="to_add@some_example.com"

#IMPORTANT: Type of node
solr_node=false

#number of attempts information
max_attempts=3
max_attempt_file_path=/usr/cassandra/bin/attempts
interval=10

#Log information
export log_folder_path=/usr/cassandra/bin/restart_logs
log=`date +%d_%m_%Y`
logname="restart_"$log".log"
log_path=$log_folder_path"/"$logname
host=`hostname`

#create the temp directories
mkdir -p $log_folder_path
mkdir -p $max_attempt_file_path




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


agent_id=$(ps -ef | grep datastax-agent | grep -v grep | awk '{ print $2 }')
ops_version=""

if [ -n "$agent_id" ]; then
   #ops_version=`find /opt/cassandra/ -type d -name "*" -exec find {} -name "opscenter*" \;| sort -r|egrep -o "*/opscenter-*([0-9]{1,}\.)+[0-9]{1,}"|cut -c2- |awk 'NR==1{print $1}'`
   ops_version=`ps -ef |grep datastax-agent|grep -v grep | grep -v 'startCassandra[.]sh' | grep -v 'cqlsh*'|egrep -o "datastax-agent-*([0-9]{1,}\.)+[0-9]{1,}"|cut -c1- |awk 'NR==1{print $1}'`
   echo "`date` INFO: Running OPSCenter agent Version: $ops_version"
else
#   ops_version=`find /opt/cassandra/ -type d -name "*" -exec find {} -name "opscenter*" \;| sort -r|egrep -o "*/opscenter-*([0-9]{1,}\.)+[0-9]{1,}"|cut -c2- |awk 'NR==1{print $1}'`
   ops_version=`find /opt/cassandra -type d -name "*" -exec find {} -name "datastax-agent*" \;| sort -u|egrep -o "*/datastax-agent-*([0-9]{1,}\.)+[0-9]{1,}"|cut -c2- |awk 'NR==1{print $1}'`
if [ -z "$ops_version" ]; then
      echo "`date` ERROR: No OPSCenter  binary present in the path"
   else
      echo "`date` ERROR: datastax-agent is not running currently. Latest binary version present: $ops_version"

   fi
fi

export cassandra_bin_path=/usr/cassandra/instance/bin
export cassandra_conf_path=/usr/cassandra/instance/conf
export agent_path=/usr/cassandra/${ops_version}/bin



if [ -n "$ops_version" ]; then
        processes=cassandra,datastax-agent
else
        processes=cassandra
fi

run_method=""

if [ -z "$PS1" ]; then
    run_method="from :CRON"
else
    run_method=":MANUALLY"
fi

#dse_counter=0
#ops_counter=0

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

file1=${max_attempt_file_path}/cassandra_counter
if [ ! -e "$file1" ] ; then
    touch "$file1"
fi

file2=${max_attempt_file_path}/ops_counter
if [ ! -e "$file2" ] ; then
    touch "$file2"
fi



for process in ${processes//,/ }
do

while true; do

        cassandra_counter=$(cat ${max_attempt_file_path}/cassandra_counter)
        ops_counter=$(cat ${max_attempt_file_path}/ops_counter)

        #ps cax | grep cassandra > /dev/null
        #process_id=$(ps xu | grep $process | grep -v grep | awk '{ print $2 }')
        if [ "$process" == "cassandra" ] ; then
                #process_id=$(ps -ef | grep cassandra | grep -v grep | grep -v 'startCassandra[.]sh' | grep -v 'cqlsh*'|awk '{ print $2 }')
                process_id=$(ps -ef | grep 'org.apache.cassandra.service.CassandraDaemon*' | grep -v grep | grep -v 'startCassandra[.]sh' | grep -v 'cqlsh*'|awk '{ print $2 }')
        else
                process_id=$(ps -ef | grep $process | grep -v grep | awk '{ print $2 }')
        fi
        echo "`date` INFO: $process process id: $process_id"
        #if [ $process_id -ne 0 ]; then

        #Running situation
        if [ -n "$process_id" ]; then
          echo "`date` INFO: $process is currently running"
                #Reset the counter files
                if [ "$process" == "cassandra" ] ; then
                        echo "0" > $max_attempt_file_path/cassandra_counter
                        rm $max_attempt_file_path/${process}_final_attempt 2> /dev/null
                else
                        echo "0" > $max_attempt_file_path/ops_counter
                        rm $max_attempt_file_path/${process}_final_attempt 2> /dev/null
                fi
        #Not running situation
        elif [[ "$cassandra_counter" -eq "$max_attempts"  ||  "$ops_counter" -eq "$max_attempts" && ! -f ${max_attempt_file_path}/${process}_final_attempt ]]; then
           echo -e "Failed to restart $process in the host $host after $max_attempts attempts \n \nPlease check logs in the path for any error: $log_path" | mailx -s "FAILED: $process HOST:$host" -r $from_email_address  $to_email_address
           touch ${max_attempt_file_path}/${process}_final_attempt
           echo "`date` ERROR: Already tried $max_attempts attempts to restart the $process from the script. Please try restarting it manually."

        else
        #echo "not running "
          if [[ "$send_mail" = true && "$process" == "cassandra" ]] ; then

          echo -e " Restarting cassandra $run_method \n Host: $host \n Attempt: `expr ${cassandra_counter} + 1`(out of $max_attempts) \n After $max_attempts attempts $process will not be restarted \n Date Time: `date` \n \n Please check logs in the path for any error: $log_path" | mailx -s "RESTARTING: cassandra HOST:$host" -r $from_email_address  $to_email_address
          fi
          if [ "$type" = "cron" ]; then
                echo "`date`ERROR: $process Process is not running." >> $log_path
                echo "`date` INFO: Starting $process. Please wait...." >> $log_path
          else
                echo "`date`ERROR: $process Process is not running."
                echo "`date` INFO: Starting $process. Please wait...."
          fi
          if [[ "$process" == "cassandra"  &&   "$cassandra_counter" -lt "$max_attempts" ]]; then
                cassandra_counter=`expr $cassandra_counter + 1`
                echo $cassandra_counter > $max_attempt_file_path/cassandra_counter
                if [ "$solr_node" = true ] ; then
                        $cassandra_bin_path/cassandra -s >> $log_path
                else
                        $cassandra_bin_path/cassandra >> $log_path
                fi
          elif [[ "$process" = "datastax-agent"  && "$ops_counter" -lt "$max_attempts" ]]; then
                ops_counter=`expr $ops_counter + 1`
                echo $ops_counter > $max_attempt_file_path/ops_counter
                $agent_path/datastax-agent >> $log_path
          fi
          echo "`date`ERROR: Waiting for $interval seconds..."
          #sleep $interval
          progress_bar $interval
          echo ""
          process_id=$(ps xu | grep $process | grep -v grep | awk '{ print $2 }')
          continue
        fi
        break
done
done
if [ "$type" = "manual" ]; then
echo "`date` INFO: Please check logs in the path: $log_path"
fi
