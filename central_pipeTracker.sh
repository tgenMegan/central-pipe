#!/bin/bash
time=`date +%d-%m-%Y-%H-%M`
echo "Starting $0 at $time"
myHostName=`hostname`	

trackerDir="/scratch/mrussell/centralPipe/pipeTracker/"
topCentralProjDir="/scratch/mrussell/centralPipe/projects"
timeExt="_ps"`date +%Y%m%d%H%M`
workingTrackerFile="/scratch/mrussell/centralPipe/pipeTracker/pipelineTracking${timeExt}.txt"

findCount=`ps -e | awk '$4=="find"' | wc -l`
if [ $findCount -ge 3 ] ; then
    echo "Too many finds on $myhostname ($findCount) already, quitting for $myhostname!!!"
    exit
else
    echo "Find count is low on $myhostname ($findCount)."
fi
touch $workingTrackerFile

#Goes through each project in the central pipeline
for project in `ls $topCentralProjDir`
do
	echo "Now in project $project"
	shortName=`echo $project | awk -F'_ps20' '{print $1}'`
	configFile=$topCentralProjDir/$project/$shortName.config
	for sampleLine in `cat $configFile | grep ^SAMPLE=`
	do
		kitName=`echo $sampleLine | cut -d= -f2 | cut -d, -f1`
        	samName=`echo $sampleLine | cut -d= -f2 | cut -d, -f2`
        	assayID=`echo $sampleLine | cut -d= -f2 | cut -d, -f3`
        	libraID=`echo $sampleLine | cut -d= -f2 | cut -d, -f4`
		email=`cat $configFile | grep "^EMAIL=" | cut -d= -f2 | head -1 | tr -d [:space:]`	
		echo "Now looking for Queue files for sample: $samName"
		for queueFile in `find $topCentralProjDir/$project -maxdepth 6 -name "${samName}*InQueue*" `
		do
			#figure out what process it is
			queue=`basename $queueFile`
			queue=`echo $queue | rev | cut -d. -f1 | rev`
			process=`echo ${queue/InQueue}`
			lastModified=`date -r $queueFile` 
			echo "$project;$samName;$assayID;$email;$process;InQueue;$lastModified"	>> $workingTrackerFile	
	
		done
		echo "Now looking for Pass files for sample: $samName"
		for passFile in `find $topCentralProjDir/$project -maxdepth 6 -name "${samName}*Pass*" `
                do
                        #figure out what process it is
                        pass=`basename $passFile`
                        pass=`echo $pass | rev | cut -d. -f1 | rev`
                        process=`echo ${pass/Pass}`
                        lastModified=`date -r $passFile`
                        echo "$project;$samName;$assayID;$email;$process;Pass;$lastModified"  >> $workingTrackerFile

                done
		echo "Now looking for Fail files for sample: $samName"
                for failFile in `find $topCentralProjDir/$project -maxdepth 6 -name "${samName}*Fail*" `
                do
                        #figure out what process it is
                        fail=`basename $failFile`
                        fail=`echo $fail | rev | cut -d. -f1 | rev`
                        process=`echo ${fail/Fail}`
                        lastModified=`date -r $failFile`
                        echo "$project;$samName;$assayID;$email;$process;Fail;$lastModified"  >> $workingTrackerFile

                done
	done

done

time=`date +%d-%m-%Y-%H-%M`
echo "Ending $0 at $time"
