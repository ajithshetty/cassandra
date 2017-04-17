
#!/bin/ksh
#set -x

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


days=$1
export DataDir=/usr/cassandra/data
export cassandra_bin_path=/usr/cassandra/instance/bin
export log_dir=/usr/cassandra/bin/clearsnapshot_logs
send_mail=false
from_email_address="from@some_example.com"
to_email_address="to@some_example.com"
remove_dir_created_while_truncate=true


snap_list=""
mkdir -p $log_dir


if [[ $#  != 1 ]]
then
echo " usage is: ./clearOldSnaps.sh x "
echo "x is a parameter to remove snapshots older than (current date - x days) based on filesystem timestamps"

exit
fi

#tmstmp=`date +'%Y%m%d%H%M%S' `
tmstmp=`date +%s`

hostname=`hostname`
today=`date +'%Y%m%d%H%M%S' `





for keySpace in `ls $DataDir`
do
        for cf in `ls $DataDir/$keySpace `
        do
           if [ -d "$DataDir/$keySpace/$cf/snapshots" ]; then
                if ! [ -z $DataDir/$keySpace/$cf/snapshots ]; then

                for snapNm in `find  $DataDir/$keySpace/$cf/snapshots/ -mtime +$days -type d -print `
                do
                        snapName=`basename $snapNm `
                        if [ "$snapName" -eq "snapshots" ];then
                        continue
                        fi

                        echo "Deleting snapshot older than $days : `ls -ldc $snapNm`"
                        re='^[0-9]+$'
                        if ! [[ $snapName =~ $re ]];then
                                if [ "$remove_dir_created_while_truncate" = true ];then
                                echo "snapshot $snapNm is older than $days day(s)" >> $log_dir/${today}_clearsnapshot
                                $cassandra_bin_path/nodetool clearsnapshot $keySpace -t $snapName >> $log_dir/${today}_clearsnapshot
                                snap_list=${snap_list}"'\n'"${snapNm}
                                fi
                        else
                                echo "snapshot $snapNm is older than $days day(s)" >> $log_dir/${today}_clearsnapshot
                                $cassandra_bin_path/nodetool clearsnapshot $keySpace -t $snapName >> $log_dir/${today}_clearsnapshot
                                snap_list=${snap_list}"'\n'"${snapNm}

                        fi
                done
                fi
           fi
        done
done

list=`echo $snap_list|cut -c2-`
if [ "$send_mail" = true ] && [ ${#list} -gt 1 ] ; then
          echo -e "nodetool clear snapshot process completed for the snapshot directories older than $days day(s). \nHost: $hostname \nDate Time: `date` \n \nPlease check logs in the path for any error: $log_dir/${today}_clearsnapshot_* \nList of deleted snapshots:\n${list}" | mailx -s "CLEARING SNAPSHOTS in the host:$hostname" -r $from_email_address  $to_email_address
fi

