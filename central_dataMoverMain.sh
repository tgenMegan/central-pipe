#!/bin/bash
#####################################################################
# Copyright (c) 2011 by The Translational Genomics Research
# Institute Ahmet Kurdoglu. All rights reserved. This License is limited 
# to, and you may use the Software solely for, your own internal and i
# non-commercial use for academic and research purposes. Without limiting 
# the foregoing, you may not use the Software as part of, or in any way 
# in connection with the production, marketing, sale or support of any 
# commercial product or service or for any governmental purposes. For 
# commercial or governmental use, please contact dcraig@tgen.org. By 
# installing this Software you are agreeing to the terms of the LICENSE 
# file distributed with this software.
#####################################################################
source ~/.bashrc
time=`date +%d-%m-%Y-%H-%M`
echo "Starting $0 at $time"
scriptsHome="/home/mrussell/central-pipe"
logs="/scratch/mrussell/centralPipe/logs"
topProjDir="/scratch/mrussell/centralPipe/projects"
myhostname=`hostname`

echo "### ~~Running on $myhostname~~"

findCount=`ps -e | awk '$4=="find"' | wc -l`
if [ $findCount -ge 2 ] ; then
    echo "Too many finds on $myhostname ($findCount) already, quitting for $myhostname!!!"
    exit
else
    echo "Find count is low on $myhostname ($findCount)."
fi

for messageFile in `find $topProjDir -maxdepth 2 -name central_nextJob_*txt`
do
	projDir=`dirname $messageFile`
	msgName=`basename $messageFile`
	echo "### Message file: $msgName"
	case $msgName in
	central_nextJob_saveToIsilon.txt)	echo "### Will save to Isilon $projDir"
		nohup $scriptsHome/central_saveToIsilon.sh $projDir >> $projDir/logs/central_saveToIsilonLOG.txt 2>&1 &
		sleep 1
		;;
	central_nextJob_saveStats.txt)		echo "### Will save stats to Isilon $projDir"
		nohup $scriptsHome/central_saveStats.sh $projDir >> $projDir/logs/central_saveStatsLOG.txt 2>&1 &
		sleep 1
		;;
	central_nextJob_saveToReport.txt)          echo "### Will save stats to Isilon $projDir"
                nohup $scriptsHome/central_saveToReport.sh $projDir >> $projDir/logs/central_saveToReportLOG.txt 2>&1 &
                sleep 1
                ;;
	*) 	echo "### Nothing to process $msgName with on $myhostname. Skipped."
		sleep 1
		;;
	esac
done

echo "### Sending collect fastqs into collectFQdropBox..."
$scriptsHome/central_collectFastqs.sh >> $logs/central_collectFastqsLOG.txt 2>&1
echo "### End of collect fastqs checking out collectFQdropBox."

echo "**********DONE************"
