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

thisStep="central_nextJob_saveToIsilon.txt"
nxtStep1="central_nextJob_postSaveToIsilon.txt"
pbsHome="/home/mrussell/central-pipe/jobScripts"
constants="/home/mrussell/central-pipe/constants/constants.txt"
constantsDir="/home/mrussell/central-pipe/constants"
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

email=`cat $configFile | grep "^EMAIL=" | cut -d= -f2 | head -1 | tr -d [:space:]`
results=`cat $configFile | grep "^RESULTS=" | cut -d= -f2 | head -1 | tr -d [:space:]`
saveRecipe=`cat $configFile | grep "^SAVERECIPE=" | cut -d= -f2 | head -1 | tr -d [:space:]`
recipe=`cat $configFile | grep "^RECIPE=" | cut -d= -f2 | head -1 | tr -d [:space:]`
debit=`cat $configFile | grep "^DEBIT=" | cut -d= -f2 | head -1 | tr -d [:space:]`
saveSimple=`cat $configFile | grep "^SAVESIMPLE=" | cut -d= -f2 | head -1 | tr -d [:space:]`

if echo $saveSimple | grep -iq yes  ; then
	echo "SAVESIMPLE $saveSimple is going to run"
else
	echo "SAVESIMPLE $saveSimple is not going to run"
fi

nCores=`grep @@${myName}_CORES= $constantsDir/$recipe | cut -d= -f2`
ref=`grep "@@"$recipe"@@" $constants | grep @@REF= | cut -d= -f2`

echo "### projName: $projName"
echo "### confFile: $configFile"
echo "### saveSimple: $saveSimple"

d=`echo $runDir | cut -c 2-`

targetDir="$results"
if [ "$targetDir" = "" ] ; then
	echo "RESULTS in $runDir bad or not there: $targetDir"
	echo "Exiting!!!"	
	exit
fi
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
echo "### Copy process started at $time" > $runDir/copying.txt
echo "### Copy process started at $time" > $targetDir/copyStarted.txt

echo "### Save recipe is $saveRecipe"
extensions=`cat /home/mrussell/central-pipe/constants/saveRecipes.txt | grep "^$saveRecipe=" | cut -d= -f2 | head -1 | tr -d [:space:]`
echo "### Extensions to copy are $extensions"
fails=0

if echo $saveSimple | grep -iq yes  ; then
	
	echo "This will save back with the saveSimple option"
	mkdir -p $targetDir/bams
	if [ $? -eq 0 ] ; then
		echo "bams directory is: $targetDir/bams"
	else
		echo "could not create $targetDir/bams"
		echo "Exiting!!!"       
		exit
	fi

	mkdir -p $targetDir/fastqs
	if [ $? -eq 0 ] ; then
		echo "fastqs directory is: $targetDir/fastqs"
	else
		echo "could not create $targetDir/fastqs"
		echo "Exiting!!!"       
		exit
	fi

	mkdir -p $targetDir/vcfs
	if [ $? -eq 0 ] ; then
		echo "vcfs directory is: $targetDir/vcfs"
	else
		echo "could not create $targetDir/vcfs"
		echo "Exiting!!!"       
		exit
	fi

	mkdir -p $targetDir/runInfo
	if [ $? -eq 0 ] ; then
		echo "runInfo directory is: $targetDir/runInfo"
	else
		echo "could not create $targetDir/runInfo"
		echo "Exiting!!!"       
		exit
	fi
        mkdir -p $targetDir/stats
        if [ $? -eq 0 ] ; then
                echo "stats directory is: $targetDir/stats"
        else
                echo "could not create $targetDir/stats"
                echo "Exiting!!!"       
                exit
        fi
        mkdir -p $targetDir/images
        if [ $? -eq 0 ] ; then
                echo "images directory is: $targetDir/images"
        else
                echo "could not create $targetDir/images"
                echo "Exiting!!!"       
                exit
        fi
        mkdir -p $targetDir/other
        if [ $? -eq 0 ] ; then
                echo "misc directory is: $targetDir/other"
        else
                echo "could not create $targetDir/other"
                echo "Exiting!!!"       
                exit
        fi
	bamsPath="$targetDir/bams"
	fastqsPath="$targetDir/fastqs"
	vcfsPath="$targetDir/vcfs"
	runInfo="$targetDir/runInfo"
	statsPath="$targetDir/stats"
	otherPath="$targetDir/other"
	imagesPath="$targetDir/images"

	for ext in `echo $extensions | tr "," "\n"`
	do
		#echo "ext to look for $ext"
		for line in `find $runDir -name "*$ext"`
		do
			case "$ext" in
				*fastq.gz) echo "found fastqs"
				echo "copying $line to $fastqsPath"
				rsync -tlu $line $fastqsPath
			;;
				*bam) echo "found bam"
	                        bamSize=`stat -c%s $line`
	                        if [ $bamSize -ge 500 ] ; then
					echo "copying $line to $bamsPath"
                                	rsync -tLu $line $bamsPath
                                else
					echo "BAM: $line is only $bamSize bytes"
					echo "### This bam is smaller than 500 bytes. It is not an actual bam and wont be copied."
                     		fi 
			;;
				*bai) echo "found bam index"
                                baiSize=`stat -c%s $line`
                                if [ $baiSize -ge 300 ] ; then
                                        echo "copying $line to $bamsPath"
                                        rsync -tLu $line $bamsPath
                                else
                                        echo "BAI: $line is only $baiSize bytes"
                                        echo "### This bai is smaller than 300 bytes. It is not an actual bai and wont be copied."
                                fi
			;;
				*vcf) echo "found vcf"
				echo "copying $line to $vcfsPath"
				rsync -tlu $line $vcfsPath
			;;
                                *vcf.idx) echo "found vcf index"
                                echo "copying $line to $vcfsPath"
                                rsync -tlu $line $vcfsPath
			;;
				*totalTime) echo "found totalTime"
				echo "copying $line to $runInfo"
				rsync -tlu $line $runInfo
			;;
				*perfOut) echo "found perfOut"
				echo "copying $line to $runInfo"
				rsync -tlu $line $runInfo
			;;
                                *png) echo "found png"
                                echo "copying $line to $imagesPath"
                                rsync -tlu $line $imagesPath
			;;
				*Metrics*) echo "found Metrics"
				echo "copying $line to $statsPath"
				rsync -tlu $line $statsPath
			;;
				*metrics*) echo "found metrics"
                                echo "copying $line to $statsPath"
                                rsync -tlu $line $statsPath
			;;
		               	*Stats*) echo "found Stats"
                                echo "copying $line to $statsPath"
                                rsync -tlu $line $statsPath
			;;
		                *stats*) echo "found stats"
                                echo "copying $line to $statsPath"
                                rsync -tlu $line $statsPath
			;;
				*) echo "found everything else" 
				echo "copying $line to $otherPath"
				rsync -tlu $line $otherPath
			;;
			esac
		done
	done

	for metFile in `find $targetDir -name "*[Mm]etrics*"`
	do
		if [[ $metFile == *totalTime ]] || [[ $metFile == *perfOut ]] || [[ $metFile == *png ]] ; then
			echo "won't move a totalTime or perfOut file"
		else
			echo "mv $metFile $statsPath"
			mv $metFile $statsPath
		fi

	done
	for statFile in `find $targetDir -name "*[Ss]tats*"`
	do 
		if [[ $statFile == *totalTime ]] || [[ $statFile == *perfOut ]] || [[ $statFile == *png ]] ; then
			echo "won't move a totalTime or perfOut file"
		else	
			echo "mv $statFile $statsPath"
			mv $statFile $statsPath
		fi
	done
	if test "$(ls -A "$fastqsPath")" ; then
		echo "the fastq folder has files in it"
	else
		echo "There are no files in $fastqsPath, the folder will be deleted"
		rm -r $fastqsPath
	fi
	
else
	echo "This will save back will full directories"
	for extToCopy in `echo $extensions | tr "," "\n"`
	do
		echo "### Looking for $extToCopy extension"
		for fileToSave in `find $runDir -name "*$extToCopy"`
		do
			fileName=`basename $fileToSave`
			echo "### File to save is $fileToSave"
			base=${fileToSave/$runDir//}
			targetPath=$targetDir/$base
			targetBase=`dirname $targetPath`
			#echo "file to copy: $line"
			#echo "base is     : $base"
			#echo "target name : $targetPath"
			#echo "target base : $targetBase"
			if [ ! -d $targetBase ] ; then
				mkdir -p $targetBase
			fi
			if [ ! -e $targetPath ] ; then
				echo "### Copying $fileToSave to $targetPath"
				rsync -tlu $fileToSave $targetPath
				if [ $? -ne 0 ] ; then
					echo "### Failed to copy to $targetPath"
					rm -f $targetPath
					fails=1
				fi
			else
				echo "### Already exists: $targetPath/$fileName"
			fi
		done
	done
fi

rm -f $targetDir/copying.txt
rm -f $runDir/copying.txt

if [ $fails -eq 0 ] ; then
	echo "### Copy process finished successfully!"
	echo "### Copy process finished at $time" > $targetDir/copyDone.txt
	if [  -e $runDir/saveToIsilonEmail.sent ] ; then
		echo "Email already sent for $runDir"
	else	
		echo "Your project $projName have been copied to Isilon here: $targetDir" >> ~/mailtmp-$$.txt
		echo "This project will be automatically DELETED from our computers 14 days from this email." >> ~/mailtmp-$$.txt
		cat ~/mailtmp-$$.txt | mail -s "central pipeline: your project $projName finished analysis" "$email"
		cat ~/mailtmp-$$.txt | mail -s "central pipeline: your project $projName finished analysis" "mrussell@tgen.org"
		mv ~/mailtmp-$$.txt $runDir/saveToIsilonEmail.sent
		echo "### Mail sent and saved to $runDir/saveToIsilonEmail.sent"
	fi
	echo "### I should remove $thisStep from $runDir."
	rm $runDir/$thisStep
else
	echo "Copy process failed!"
	echo "Copy process failed at $time" > $targetDir/copyFailed.txt
fi
time=`date +%d-%m-%Y-%H-%M`
echo "Ending $0 at $time on $hn"
