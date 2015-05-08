#!/bin/bash
#####################################################################
# Copyright (c) 2013 by The Translational Genomics Research
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
#author: ahmet kurdoglu

time=`date +%d-%m-%Y-%H-%M`
echo "Starting $0 at $time"
echo ""
dropDir="/scratch/mrussell/centralPipe/dropBox/"
dbGood="/scratch/mrussell/centralPipe/dbGood/"
dbFail="/scratch/mrussell/centralPipe/dbFail/"
dbUsed="/scratch/mrussell/centralPipe/dbUsed/"
logs="/scratch/mrussell/centralPipe/logs/"

targetTopDir="/scratch/mrussell/centralPipe/projects"
conflicts="/scratch/mrussell/centralPipe/conflicts/"
mergeSheetDir="/scratch/mrussell/centralPipe/mergeInfo/"

msg1="nextJob_copyFastqs.txt"

for configFile in `find $dbGood \( -name "*config" ! -name ".*" \)`
do
	echo "### Found config file: $configFile"

	### create dir with project name and time extenstion
	timeExt="_ps"`date +%Y%m%d%H%M`
	proj=`cat $configFile | grep "^PROJECT=" | cut -d= -f2 | head -1 | tr -d [:space:]`
	pipeline=`cat $configFile | grep "^PIPELINE=" | cut -d= -f2 | head -1 | tr -d [:space:]`
	projDir=$targetTopDir/$proj$timeExt
	pedFile=${configFile/config/ped}

	echo "### Making project directory $projDir."
	mkdir -p $projDir
	mkdir -p $projDir/oeFiles
	mkdir -p $projDir/logs

	echo "### Copying fonfig file to $projDir"
	cp $configFile $projDir/$proj.config
	
        if [ -e $pedFile ] ; then
                echo "###PED file found $pedFile"
        	cp $pedFile $projDir/$proj.ped 
		mv $pedFile $dbUsed
	else
                echo "###PED file not found for this project"
        fi
	### create dir with kit name, sample name
	skipLines=1
	count=0
	sampleCount=0
	for configLine in `cat $configFile`
	do
		if [ "$configLine" == "=START" ] ; then
			skipLines=0
			continue
		fi
		if [ $skipLines -eq 0 ] ; then
			if [[ $configLine == SAMPLE* || $configLine == =END* ]] ; then
				#echo "config line is $configLine"
				arrayCount=${#mergeArray[@]}
				if [ $arrayCount -gt 0 ] ; then
					((sampleCount++))
					echo "### Making directory for kit: $kitName, sample: $samName."
					mkdir -p $targetTopDir/$proj$timeExt/$kitName/$samName
					#lastItemIndex=`echo ${#mergeArray[@]}-1 | bc`
					#for (( i=0; i<=$lastItemIndex; i++ ))
					#do
					#	echo "array with index $i is::: ${mergeArray[$i]}"
					#done
				fi
				kitName=`echo $configLine | cut -d= -f2 | cut -d, -f1`
				samName=`echo $configLine | cut -d= -f2 | cut -d, -f2`
				unset mergeArray
				count=0
				continue
			else #doesnt start with =, add to mergeArray
				mergeArray[$count]=$configLine	
				((count++))
			fi
		else
			continue
		fi
	done
	### creating message file in $projDir
	touch ${projDir}/${pipeline}_${msg1}	
	echo "### Done with config file: $configFile"
	echo "### Moving config file to dbUsed"
	mv $configFile $dbUsed
	echo ""
done
time=`date +%d-%m-%Y-%H-%M`
echo "Ended $0 at $time"
