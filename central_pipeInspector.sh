#!/bin/bash
time=`date +%d-%m-%Y-%H-%M`
echo "Starting $0 at $time"
cron=$1
if [ "$cron" == "cron" ] ; then
	echo "cron mode"
	myHostName=`hostname`	
	echo "my host name is $myHostName"
else
	echo "manual mode"
fi
dirNetChck="/scratch/mrussell/pnapPipe/dropBoxCheckNetCopy"
dirPecanPi="/scratch/mrussell/centralPipe/projects/"
dirFastqPi="/scratch/mrussell/chiaPipe/runFolders"

echo "Comparing number of *InQueue files vs number of running jobs..."
echo "searching for inQueue files in $dirNetChck"
inQueueFilesNetChck=`find $dirNetChck -maxdepth 5 -name "*InQueue*" | wc -l`
echo "searching for inQueue files in $dirPecanPi"
inQueueFilesPecanPi=`find $dirPecanPi -maxdepth 5 -name "*InQueue*" | wc -l`
echo "searching for inQueue files in $dirFastqPi"
inQueueFilesFastqPi=`find $dirFastqPi -maxdepth 5 -name "*InQueue*" | wc -l`

echo "recounting..."
inQueueFilesNetChck=`find $dirNetChck -maxdepth 5 -name "*InQueue*" | wc -l`
inQueueFilesPecanPi=`find $dirPecanPi -maxdepth 5 -name "*InQueue*" | wc -l`
inQueueFilesFastqPi=`find $dirFastqPi -maxdepth 5 -name "*InQueue*" | wc -l`
echo "nc: $inQueueFilesNetChck + pe: $inQueueFilesPecanPi + fq: $inQueueFilesFastqPi"
inQueueFiles=$(($inQueueFilesNetChck + $inQueueFilesPecanPi + $inQueueFilesFastqPi))

runningJobs=`/cm/shared/apps/torque/3.0.5/bin/qstat | grep " R " | wc -l`
queuedJobs=`/cm/shared/apps/torque/3.0.5/bin/qstat | grep " Q " | wc -l`
saguaroJobs=$(($runningJobs + $queuedJobs))

failCount=0
#echo "bettersum: $betterSum; allinq: $inQueueFiles; bfastonly: $bfastOnlyInQueueFiles"
if [ $saguaroJobs -eq $inQueueFiles ] ; then
	echo "	OK ($saguaroJobs)"
else
	echo "  FAIL (there are $saguaroJobs jobs in Q or R state and $inQueueFiles inQueue files)"
	failCount=1
fi
echo "done!"

if [ "$cron" == "cron" ] ; then
	count1=`find $dirPecanPi -maxdepth 5 -name *Fail -not -name *fastqValFail -exec ls -ltrh {} \; | wc -l`
	count2=`find $dirFastqPi -maxdepth 5 -name *Fail -not -name *fastqValFail -exec ls -ltrh {} \; | wc -l`
	failCount=$(($count1 + $count2 + $failCount))
	if [ $failCount -ne 0 ] ; then
		find $dirPecanPi -name *Fail -maxdepth 5 -not -name *fastqValFail -exec ls -ltrh {} \; >> /scratch/mrussell/centralPipe/pipeInspectorOut/newfails.txt
		find $dirFastqPi -name *Fail -maxdepth 5 -not -name *fastqValFail -exec ls -ltrh {} \; >> /scratch/mrussell/centralPipe/pipeInspectorOut/newfails.txt
		echo "  FAIL (there are $saguaroJobs jobs in Q or R state and $inQueueFiles inQueue files)" > /scratch/mrussell/centralPipe/pipeInspectorOut/newOut.txt
	fi
else
	#manual running mode
	echo "Searching $dirPecanPi for files with *Fail"
	find $dirPecanPi -maxdepth 5 -name *Fail -not -name *fastqValFail -exec ls -ltrh {} \;
	echo "done!"
	echo "Searching $dirFastqPi for files with *Fail"
	find $dirFastqPi -maxdepth 5 -name *Fail -not -name *fastqValFail -exec ls -ltrh {} \;
	echo "done!"
	#echo "Searching for bwa BAM files smaller than 10MB and older than half day"
	#find $dirPecanPi -name "*bam" -type f -size -10M -mmin +720 -exec ls -ltrh {} \;
	#echo "done!"
	echo "Searching for inQueue files older than 2 days"
	find $dirPecanPi -maxdepth 5 -name "*InQueue*" -mmin +2880 -exec ls -ltrh {} \;
	find $dirFastqPi -maxdepth 5 -name "*InQueue*" -mmin +2880 -exec ls -ltrh {} \;
	echo "done!"
fi
#following only done when running in cron mode
if [ "$cron" == "cron" ] ; then
	echo "fail count is $failCount"
	if [ $failCount -ne 0 ] ; then
		mailSend=0
		diff /scratch/mrussell/centralPipe/pipeInspectorOut/newOut.txt /scratch/mrussell/centralPipe/pipeInspectorOut/oldOut.txt
		if [ $? -ne 0 ] ; then
			echo "found issue with job count"
			mailSend=1
		fi
		diff /scratch/mrussell/centralPipe/pipeInspectorOut/newfails.txt /scratch/mrussell/centralPipe/pipeInspectorOut/oldfails.txt
		if [ $? -ne 0 ] ; then
			echo "found issue with failed jobs"
			mailSend=1
		fi
		if [ $mailSend -eq 1 ] ; then
			cat /scratch/mrussell/centralPipe/pipeInspectorOut/newOut.txt > /scratch/mrussell/centralPipe/pipeInspectorOut/tempMail.txt
			cat /scratch/mrussell/centralPipe/pipeInspectorOut/newfails.txt >> /scratch/mrussell/centralPipe/pipeInspectorOut/tempMail.txt
			mail -s "medusa pipeline: pipeInspector found issue" "mrussell@tgen.org" < /scratch/mrussell/centralPipe/pipeInspectorOut/tempMail.txt
		fi
		mv /scratch/mrussell/centralPipe/pipeInspectorOut/newOut.txt /scratch/mrussell/centralPipe/pipeInspectorOut/oldOut.txt
		mv /scratch/mrussell/centralPipe/pipeInspectorOut/newfails.txt /scratch/mrussell/centralPipe/pipeInspectorOut/oldfails.txt
		rm /scratch/mrussell/centralPipe/pipeInspectorOut/tempMail.txt
	fi
fi
time=`date +%d-%m-%Y-%H-%M`
echo "Ending $0 at $time"
