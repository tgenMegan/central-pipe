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
dropDir="/scratch/mrussell/centralPipe/bamPipeDropBox/"
dbGood="/scratch/mrussell/centralPipe/dbGood/"
dbFail="/scratch/mrussell/centralPipe/dbFail/"
dbUsed="/scratch/mrussell/centralPipe/dbUsed/"
logs="/scratch/mrussell/centralPipe/logs/"

targetTopDir="/scratch/mrussell/centralPipe/projects"
conflicts="/scratch/mrussell/centralPipe/conflicts/"
mergeSheetDir="/scratch/mrussell/centralPipe/mergeInfo/"
#ref=`cat $configFile | grep "^REF=" | cut -d= -f2 | head -1 | tr -d [:space:]`
msg1="medusa_nextJob_haplotypeCaller.txt"
msg2="medusa_nextJob_picardMultiMetrics.txt"
msg3="medusa_nextJob_samtoolsStats.txt"
msg4="medusa_nextJob_seurat.txt"
msg5="medusa_nextJob_strelka.txt"
msg6="medusa_nextJob_mutect.txt"
msg7="medusa_nextJob_trn.txt"
msg8="medusa_nextJob_cna.txt"
msg9="medusa_nextJob_snpSniff.txt"
msg10="medusa_nextJob_clonalCov.txt"

for configFile in `find $dropDir \( -name "*config" ! -name ".*" \)`
do
	echo "### Found config file: $configFile"

	### create dir with project name and time extenstion
	timeExt="_ps"`date +%Y%m%d%H%M`
	proj=`cat $configFile | grep "^PROJECT=" | cut -d= -f2 | head -1 | tr -d [:space:]`
	pipeline=`cat $configFile | grep "^PIPELINE=" | cut -d= -f2 | head -1 | tr -d [:space:]`
	projDir=$targetTopDir/$proj$timeExt
	echo "### Making project directory $projDir."
	mkdir -p $projDir
	mkdir -p $projDir/oeFiles
	mkdir -p $projDir/logs

	echo "### Copying config file to $projDir"
	cp $configFile $projDir/$proj.config

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
				echo "arrayCount is: $arrayCount"
				if [ $arrayCount -gt 0 ] ; then
					((sampleCount++))
					echo "### Making directory for kit: $kitName, sample: $samName."
					mkdir -p $targetTopDir/$proj$timeExt/$kitName/$samName
					
					### Copying ###
					targetName=$targetTopDir/$proj$timeExt/$kitName/$samName/$samName.proj.md.jr.bam
					targetBai=$targetTopDir/$proj$timeExt/$kitName/$samName/$samName.proj.md.jr.bai
					thisBam=`echo ${mergeArray[$i]} | cut -d= -f2 | cut -d, -f2`
					wantedBai=${thisBam/.bam/.bai}

					if [[ -e $thisBam.bai ]] ; then
						thisBai=$thisBam.bai        				
					elif [[ -e $wantedBai ]] ; then
						thisBai=$wantedBai
					else
						echo "### The bam index file was not found"
					fi

					if [[ ! -e $targetName.cpBamInQueue && ! -e $targetName.cpBamPass ]] ; then
					#	if [ "$incFastq" == "yes" ] ; then
							echo "### Copying to $targetName"
							touch $targetName.cpBamInQueue
							cp $thisBam $targetName
						  	cp $thisBai $targetBai	
							if [ $? -eq 0 ] ; then
								touch $targetName.cpBamPass
							else
								touch $targetName.cpBamFail
							fi
							rm -f $targetName.cpBamInQueue
							touch $targetName.jointIRPass
					#	else #must be no, not copying, just linking
					#		echo "### Linking for $thisFq to $targetName"
					#		ln -s $thisFq $targetName
					#		if [ $? -eq 0 ] ; then
					#			touch $targetName.cpBamPass
					#		else
					#			touch $targetName.cpBamFail
					#		fi
					#	fi
					else
						echo "### Copy already in queue or passed $targetName " 
					fi


					###	

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
	numJirSet=`cat $configFile | grep '^JIRSET=' | wc -l`
	if [ $numJirSet -eq 0 ] ; then
        	echo "There was no JIRSET line, will run with DNAPAIR/DNAFAMI"
        	jirLine="^DNAPAIR=\|^DNAFAMI="
	else
        	echo "There was a JIRSET line, will run with JIRSET"
        	jirLine="^JIRSET="
	fi
	
	for dnaPairLine in `cat $configFile | grep $jirLine`
	do
		echo "### DNA pair line is $dnaPairLine"
		sampleNames=`echo $dnaPairLine | cut -d= -f2 | cut -d ';' -f1`
		nickName=`echo $dnaPairLine | cut -d ';' -f2`
		if [[ $nickName == DNAPAIR*  ]] ; then
			echo "There isnt a nickname for this line, will use all sample names"
			usableName=${sampleNames//,/-}
			echo "usableName: $usableName"
		else
			echo "The nickname for this JIRSET or DNAFAMI is $nickName"
			usableName="$nickName"
        	fi
        	echo "sampleNames: $sampleNames"
	
		jirDir="$targetTopDir/$proj$timeExt/jointIR"
        	if [ ! -d $jirDir ] ; then
                	mkdir $jirDir
        	fi
        	mkdir -p $jirDir/$usableName
		#####
		
		### Next Step ###
		pair1=`echo $dnaPairLine | cut -d= -f2 | cut -d ',' -f1`
		pair2=`echo $dnaPairLine | cut -d= -f2 | cut -d ',' -f2`
		normalBamFile=$jirDir/$usableName/$pair1.proj.md.jr.bam
		tumorBamFile=$jirDir/$usableName/$pair2.proj.md.jr.bam

		echo "### normal BAM: $normalBamFile"
		echo "### tumor  BAM: $tumorBamFile"

		normalBaiFile=${normalBamFile/.bam/.bai}
		tumorBaiFile=${tumorBamFile/.bam/.bai}
		
		if [[ ! -e $normalBamFile ]] ; then
			touch $normalBamFile
		fi

		if [[ ! -e $tumorBamFile ]] ; then
                        touch $tumorBamFile
                fi

		if [[ ! -e $jirDir/$usableName/$usablename.jointIRPass ]] ; then
			echo "JointIRPass was created in $jirDir/$usableName"
			touch $jirDir/$usableName/$usableName.jointIRPass
		fi
		#touch file names and pass file name here
		#####
	done

	### creating message file in $projDir
	touch ${projDir}/${msg1}
	touch ${projDir}/${msg2}
	touch ${projDir}/${msg3}
	touch ${projDir}/${msg4}
	touch ${projDir}/${msg5}
	touch ${projDir}/${msg6}
	touch ${projDir}/${msg7}
	touch ${projDir}/${msg8}
	touch ${projDir}/${msg9}
	touch ${projDir}/${msg10}

	echo "### Done with config file: $configFile"
	echo "### Moving config file to dbUsed"
	mv $configFile $dbUsed
	echo ""
done
time=`date +%d-%m-%Y-%H-%M`
echo "Ended $0 at $time"
