#!/bin/bash
#####################################################################
# Copyright (c) 2011 by The Translational Genomics Research
# Institute. All rights reserved. This License is limited to, and you may
# use the Software solely for, your own internal and non-commercial use
# for academic and research purposes. Without limiting the foregoing, you
# may not use the Software as part of, or in any way in connection with
# the production, marketing, sale or support of any commercial product or
# service or for any governmental purposes. For commercial or governmental
# use, please contact dcraig@tgen.org. By installing this Software you are
# agreeing to the terms of the LICENSE file distributed with this
# software.
#####################################################################

thisStep="central_nextJob_saveStats.txt"
#nxtStep1="central_nextJob_postSaveToIsilon.txt"
pbsHome="/home/mrussell/central-pipe/jobScripts"
constants="/scratch/mrussell/centralPipe/constants/constants.txt"
constantsDir="/scratch/mrussell/centralPipe/constants"
myName=`basename $0`

hn=`hostname`
time=`date +%d-%m-%Y-%H-%M`
echo "Starting $0 at $time on $hn"

runDir=$1
projName=`basename $runDir`
shortName=`basename $runDir | awk -F'_ps20' '{print $1}'`

findCount=`ps -e | awk '$4=="find"' | wc -l`
if [ $findCount -ge 2 ] ; then
    echo "Too many finds on $hn ($findCount) already, quitting for $projName!!!"
    exit
else
    echo "Find count is low on $hn ($findCount)."
fi

cpCount=`ps -e | awk '$4=="rsync"' | wc -l`
if [ $cpCount -ge 6 ] ; then
    echo "Too many copies on $hn ($cpCount) already, quitting for $projName!!!"
    exit
else
    echo "Copy count is low on $hn ($cpCount)."
fi

if [ "$1" == "" ] ; then
	echo "### Please provide runfolder as the only parameter"
	echo "### Exiting!!!"
	exit
fi
configFile=$runDir/$shortName.config
if [ ! -e $configFile ] ; then
	echo "### Config file not found at $configFile!!!"
	echo "### Exiting!!!"
	exit
else
	echo "### Config file found."
fi

#email=`cat $configFile | grep "^EMAIL=" | cut -d= -f2 | head -1 | tr -d [:space:]`
#results="/ngd-data/Craig_lab/pipelineStats/"
#saveRecipe=`cat $configFile | grep "^SAVERECIPE=" | cut -d= -f2 | head -1 | tr -d [:space:]`
#recipe=`cat $configFile | grep "^RECIPE=" | cut -d= -f2 | head -1 | tr -d [:space:]`
#debit=`cat $configFile | grep "^DEBIT=" | cut -d= -f2 | head -1 | tr -d [:space:]`
#nCores=`grep @@${myName}_CORES= $constantsDir/$recipe | cut -d= -f2`
#ref=`grep "@@"$recipe"@@" $constants | grep @@REF= | cut -d= -f2`

echo "### projName: $projName"
echo "### confFile: $configFile"
d=`echo $runDir | cut -c 2-`

targetDir="/ngd-data/Craig_lab/pipelineStats/"
#if [ "$targetDir" = "" ] ; then
#	echo "RESULTS in $runDir bad or not there: $targetDir"
#	echo "Exiting!!!"	
#	exit
#fi
targetDir=$targetDir/$projName
if [ -e $targetDir/copying.txt ] ; then
	echo "### Copy already in progress now..."
	echo "### Exiting!!!"
	rm $runDir/$thisStep
	exit
fi
if [ -e $targetDir/copyDone.txt ] ; then
	echo "### Copy already done."
	echo "Exiting!!!"
	rm $runDir/$thisStep
	exit
fi
if [ -e $targetDir/copyFailed.txt ] ; then
	echo "### Copy already failed."
	echo "Exiting!!!"
	exit
fi

mkdir -p $targetDir
if [ $? -eq 0 ] ; then
	echo "### Target directory is: $targetDir"
else
	echo "### Could not create $targetDir"
	echo "### Exiting!!!"	
	exit
fi
mkdir -p $targetDir/totalTimes
mkdir -p $targetDir/performanceStats
totalTimesDir="$targetDir/totalTimes"
perfStatsDir="$targetDir/performanceStats"

#if project.finished is not there do not start copying
if [ ! -e $runDir/project.finished ] ; then
        echo "$runDir/project.finished does not exist yet"
        time=`date +%d-%m-%Y-%H-%M`
        echo "Ending $0 at $time"
        exit
fi
#if saraStats is not done yet do not start copying
if [ ! -e $runDir/summaryStatsPass ] ; then
        echo "$runDir/summaryStatsPass does not exist yet"
        time=`date +%d-%m-%Y-%H-%M`
        echo "Ending $0 at $time"
        exit
fi

echo "### Copy process started at $time" > $targetDir/copying.txt
echo "### Copy process started at $time" > $targetDir/copyStarted.txt

fails=0
for totalTimeFile in `find $runDir -maxdepth 6 -name "*totalTime"`
do
        rsync -tl $totalTimeFile $totalTimesDir
	if [ $? -ne 0 ] ; then
             echo "### Failed to copy to $totalTimeFile to $totalTimesDir"
             fails=1
        fi
done

for perfOutFile in `find $runDir -maxdepth 6 -name "*perfOut"`
do
	rsync -tl $perfOutFile $perfStatsDir
        if [ $? -ne 0 ] ; then
             echo "### Failed to copy to $totalTimeFile to $perfStatsDir"
             fails=1
        fi
done

summaryStats=`find $runDir -maxdepth 2 -name "Summary_allStats.txt"`
rsync -tl $configFile $targetDir
if [ $? -ne 0 ] ; then
     echo "### Failed to copy to $configFile to $targetDir"
     fails=1
fi

rsync -tl $summaryStats $targetDir
if [ $? -ne 0 ] ; then
     echo "### Failed to copy to $summaryStats to $targetDir"
     fails=1
fi

rm -f $targetDir/copying.txt

if [ $fails -eq 0 ] ; then
	echo "### Copy process finished successfully!"
	echo "### Copy process finished at $time" > $targetDir/copyDone.txt
	if [  -e $runDir/saveStatsEmail.sent ] ; then
		echo "Email already sent for $runDir"
	else	
		echo "Stats were saved for $projName." >> ~/mailtmp-$$.txt
		cat ~/mailtmp-$$.txt | mail -s "central pipeline: stats were saved for $projName" "mrussell@tgen.org"
		mv ~/mailtmp-$$.txt $runDir/saveStatsEmail.sent
		echo "### Mail sent and saved to $runDir/saveStatsEmail.sent"
	fi
	echo "### I should remove $thisStep from $runDir."
	rm $runDir/$thisStep
else
	echo "Copy process failed!"
	echo "Copy process failed at $time" > $targetDir/copyFailed.txt
fi
time=`date +%d-%m-%Y-%H-%M`
echo "Ending $0 at $time on $hn"
