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

targetTopDir="/scratch/mrussell/centralPipe/runFolders/"
conflicts="/scratch/mrussell/centralPipe/conflicts/"
mergeSheetDir="/scratch/mrussell/centralPipe/mergeInfo/"

for configFile in `find $dropDir \( -name "*config" ! -name ".*" \)`
do
	validateFails=0
	echo "### Found config file: $configFile"
	echo "### Correcting config file..."
	dos2unix -q $configFile
	tr '\r' '\n' < $configFile > $configFile.tmp
	mv $configFile.tmp $configFile

	### check if we can process this config or just hold it
	hc=`cat $configFile | grep "^HOLDCONFIG=" | cut -d= -f2 | tr -d [:space:]`
	if [ "$hc" == "Yes" ] ; then
		echo "### Holding this config file because HOLDCONFIG is yes"
		chmod 777 $configFile
		continue
	fi

	echo "### Checking fields in config file..."
	configName=`basename $configFile`

	#cleaning up previous errors
	rm -f $conflicts/$configName.configErrors

	### validate email address
	email=`cat $configFile | grep "^EMAIL=" | cut -d= -f2 | tr -d [:space:]`
	if [[ "$email" == ?*@?*.?* ]] ; then
		echo "### EMAIL: $email"
	else
		echo "### Bad email address found!!!"
		echo "### Bad email address found!!!" >> $conflicts/$configName.configErrors
		validateFails=1
	fi

	### validate number of fastq lines
	fqLineCount=`cat $configFile | grep ^FQ= | wc -l`
	if [ $fqLineCount -lt 1 ] ; then
		echo "### Number of fastq lines needs to be 1 at least!!!"
		echo "### Number of fastq lines needs to be 1 at least!!!" >> $conflicts/$configName.configErrors
		validateFails=1
	else
		echo "### FASTQ lines: $fqLineCount"
	fi

	### validate fastq files
	for fqLine in `cat $configFile | grep ^FQ=`
	do
		fqFile=`echo $fqLine | cut -d= -f2 | cut -d, -f2`
		if [[ ! -e $fqFile ||  "$fqFile" == "" ]] ; then
			echo "### File doesnt exist or line is blank: $fqFile"
			echo "### File doesnt exist or line is blank: $fqFile" >> $conflicts/$configName.configErrors
			validateFails=1
		fi
		#r2File=${fqFile/_R1/_R2}
		r2File=`echo $fqFile | sed 's/\(.*\)_R1_/\1_R2_/'`
		if [[ ! -e $r2File ||  "$r2File" == "" ]] ; then
			echo "### File doesnt exist or line is blank: $r2File"
			echo "### File doesnt exist or line is blank: $r2File" >> $conflicts/$configName.configErrors
			validateFails=1
		fi
	done
	### validate fastq read group exists
	for fqLine in `cat $configFile | grep ^FQ=`
	do
		fqReadGroup=`echo $fqLine | cut -d= -f2 | cut -d, -f1`
		if [[ -z "$fqReadGroup" ]] ; then
			echo "### Fastq read group needs to be defined $fqReadGroup"
			echo "### Fastq read group needs to be defined $fqReadGroup" >> $conflicts/$configName.configErrors
			validateFails=1
		fi
	done

	### validate project name
	proj=`cat $configFile | grep "^PROJECT=" | cut -d= -f2 | head -1 | tr -d [:space:]`
	if [[ -z "$proj" ]] ; then
		echo "### Project name needs to be set $proj"
		echo "### Project name needs to be set $proj" >> $conflicts/$configName.configErrors
		validateFails=1
	fi

	### validate fastq keep type
	#incFq=`cat $configFile | grep "^INCFASTQ=" | cut -d= -f2 | head -1 | tr -d [:space:]`
	#if [[ "$incFq" != "yes" && "$incFq" != "no" ]] ; then
	#	echo "### Include fastq variable INCFASTQ needs to be set $incFq"
	#	echo "### Include fastq variable INCFASTQ needs to be set $incFq" >> $conflicts/$configName.configErrors
	#	validateFails=1
	#fi

	### validate indel realign request
	#ir=`cat $configFile | grep "^INDELREALIGN=" | cut -d= -f2 | head -1 | tr -d [:space:]`
	#if [[ "$ir" != "yes" && "$ir" != "no" ]] ; then
	#	echo "### Indel realign option INDELREALIGN needs to be yes or no: $ir"
	#	echo "### Indel realign option INDELREALIGN needs to be yes or no: $ir" >> $conflicts/$configName.configErrors
	#	validateFails=1
	#fi
	#### validate base recalibration request
	#rc=`cat $configFile | grep "^RECALIBRATE=" | cut -d= -f2 | head -1 | tr -d [:space:]`
	#if [[ "$rc" != "yes" && "$rc" != "no" ]] ; then
	#	echo "### Base recalibrate option RECALIBRATE needs to be yes or no: $rc"
	#	echo "### Base recalibrate option RECALIBRATE needs to be yes or no: $rc" >> $conflicts/$configName.configErrors
	#	validateFails=1
	#fi

	### validate results directory
	results=`cat $configFile | grep "^RESULTS=" | cut -d= -f2 | head -1 | tr -d [:space:]`
	if [[ -z "$results" ]] ; then
		echo "### Results dir needs to be set $results"
		echo "### Results dir needs to be set $results" >> $conflicts/$configName.configErrors
		validateFails=1
	fi

	### validate recipe name
	recipe=`cat $configFile | grep "^RECIPE=" | cut -d= -f2 | head -1 | tr -d [:space:]`
	if [[ -z "$recipe" ]] ; then
		echo "### Recipe name needs to be set $recipe"
		echo "### Recipe name needs to be set $recipe" >> $conflicts/$configName.configErrors
		validateFails=1
	else
		grep -w "^$recipe" /home/mrussell/central-pipe/constants/validRecipes.txt > /dev/null
		if [ $? -eq 0 ] ; then
			echo "### Recipe $recipe found."
		else
			echo "### Recipe $recipe is not a valid recipe!!!"
			echo "### Recipe $recipe is not a valid recipe!!!" >> $conflicts/$configName.configErrors
			validateFails=1
		fi
	fi
	### validate pipeline name
        pipeline=`cat $configFile | grep "^PIPELINE=" | cut -d= -f2 | head -1 | tr -d [:space:]`
        if [[ -z "$pipeline" ]] ; then
                echo "### Pipeline version needs to be set $pipeline"
                echo "### Pipeline version needs to be set $pipeline" >> $conflicts/$configName.configErrors
                validateFails=1
        else
                grep -w "^$pipeline" /home/mrussell/central-pipe/constants/validPipes.txt > /dev/null
                if [ $? -eq 0 ] ; then
                        echo "### Pipeline $pipeline found."
                else
                        echo "### Pipeline $pipeline is not a valid pipeline!!!"
                        echo "### Pipeline $pipeline is not a valid pipeline!!!" >> $conflicts/$configName.configErrors
                        validateFails=1
                fi
        fi
	### validate save recipe 
	saveRecipe=`cat $configFile | grep "^SAVERECIPE=" | cut -d= -f2 | head -1 | tr -d [:space:]`
	if [[ -z "$saveRecipe" ]] ; then
		echo "### Save recipe needs to be set: $saveRecipe"
		echo "### Save recipe needs to be set: $saveRecipe" >> $conflicts/$configName.configErrors
		validateFails=1
	else
		grep -w "^$saveRecipe" /home/mrussell/central-pipe/constants/saveRecipes.txt > /dev/null
		if [ $? -eq 0 ] ; then
			echo "### Save recipe $saveRecipe found."
		else
			echo "### Save recipe $saveRecipe is not a valid recipe !!!"
			echo "### Save recipe $saveRecipe is not a valid recipe !!!" >> $conflicts/$configName.configErrors
			validateFails=1
		fi
	fi

	### validate debit account name
	debit=`cat $configFile | grep "^DEBIT=" | cut -d= -f2 | head -1 | tr -d [:space:]`
	if [[ -z "$debit" ]] ; then
		echo "### Debit name needs to be set $debit"
		echo "### Debit name needs to be set $debit" >> $conflicts/$configName.configErrors
		validateFails=1
	else
		grep -w "^$debit" /home/mrussell/central-pipe/constants/debitAccounts.txt > /dev/null
		if [ $? -eq 0 ] ; then
			echo "### Debit account $debit found."
		else
			echo "### Debit account $debit is not a valid debit account!!!"
			echo "### Debit account $debit is not a valid debit account!!!" >> $conflicts/$configName.configErrors
			validateFails=1
		fi
	fi

	for dnaPairLine in `cat $configFile | grep "DNAPAIR="`
	do
		sampleNames=`echo $dnaPairLine | cut -d= -f2`
		for eachSample in ${sampleNames//,/ }		
		do
			#this check could be better by only getting exome and dna and looking at the correct column
			cat $configFile | grep "SAMPLE=" | grep $eachSample
			if [ $? -eq 0 ] ; then
				echo "### Sample name $eachSample found."
			else
				echo "### Sample name used in DNAPAIR line needs to exist on a SAMPLE= line!!!"
				echo "### Sample name used in DNAPAIR line needs to exist on a SAMPLE= line!!!" >> $conflicts/$configName.configErrors
				validateFails=1
			fi
		done	
	done
	for dnaFami in `cat $configFile | grep "DNAFAMI="`
	do
		sampleNames=`echo $dnaFami | cut -d= -f2 | cut -d ';' -f1`
		for eachSample in ${sampleNames//,/ }		
		do
			#this check could be better by only getting exome and dna and looking at the correct column
			cat $configFile | grep "SAMPLE=" | grep $eachSample
			if [ $? -eq 0 ] ; then
				echo "### Sample name $eachSample found."
			else
				echo "### Sample name used in DNAFAMI line needs to exist on a SAMPLE= line!!!"
				echo "### Sample name used in DNAFAMI line needs to exist on a SAMPLE= line!!!" >> $conflicts/$configName.configErrors
				validateFails=1
			fi
		done	
	done

	for rnaPairLine in `cat $configFile | grep "RNAPAIR="`
	do
		sampleNames=`echo $rnaPairLine | cut -d= -f2`
		samples1=`echo $sampleNames | cut -d, -f1`
		samples2=`echo $sampleNames | cut -d, -f2`
		#for eachSample in ${sampleNames//,/ }		
		#do
			#for eachMini in ${eachSample//;/ }		
			for eachMini1 in ${samples1//;/ }		
			do
				#this check could be better by only getting exome and rna and looking at the correct column
				cat $configFile | grep "SAMPLE=" | grep $eachMini1
				if [ $? -eq 0 ] ; then
					echo "### Sample name $eachMini1 found."
				else
					echo "### Sample name $eachMini1 not found."
					echo "### Sample name used in RNAPAIR line needs to exist on a SAMPLE= line!!!"
					echo "### Sample name used in RNAPAIR line needs to exist on a SAMPLE= line!!!" >> $conflicts/$configName.configErrors
					validateFails=1
				fi
			done
			for eachMini2 in ${samples2//;/ }		
			do
				#this check could be better by only getting exome and rna and looking at the correct column
				cat $configFile | grep "SAMPLE=" | grep $eachMini2
				if [ $? -eq 0 ] ; then
					echo "### Sample name $eachMini2 found."
				else
					echo "### Sample name $eachMini2 not found."
					echo "### Sample name used in RNAPAIR line needs to exist on a SAMPLE= line!!!"
					echo "### Sample name used in RNAPAIR line needs to exist on a SAMPLE= line!!!" >> $conflicts/$configName.configErrors
					validateFails=1
				fi
			done
		#done	
	done
	for anySample in `cat $configFile | grep "SAMPLE="`
	do
		sampleName=`echo $anySample | cut -d, -f2`
		sampleCount=`cat $configFile | grep "SAMPLE=" | grep ",$sampleName," | wc -l`
		if [ $sampleCount -gt 1 ] ; then
			echo "### Sample $sampleName exists $sampleCount times in config file. We need to have just one!"
			echo "### Sample $sampleName exists $sampleCount times in config file. We need to have just one!" >> $conflicts/$configName.configErrors
			validateFails=1
		else
			echo "### Sample $sampleName found $sampleCount time."
		fi
	done

	for TRIPLET4ALLELECOUNT in `cat $configFile | grep "TRIPLET4ALLELECOUNT="`
	do
		sampleNames=`echo $tripletLine | cut -d= -f2`
		for eachSample in ${sampleNames//,/ }		
		do
			#this check could be better by only getting exome and rna and looking at the correct column
			cat $configFile | grep "SAMPLE=" | grep $eachSample
			if [ $? -eq 0 ] ; then
				echo "### Sample name $eachSample found."
			else
				echo "### Sample name used in TRIPLET4ALLELECOUNT line needs to exist on a SAMPLE= line!!!"
				echo "### Sample name used in TRIPLET4ALLELECOUNT line needs to exist on a SAMPLE= line!!!" >> $conflicts/$configName.configErrors
				validateFails=1
			fi
		done	
	done


	### validate kit name, sample name
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
					if [[ -z "$kitName" ]] ; then
						echo "### Kit name needs to be set $kitName"
						echo "### Kit name needs to be set $kitName" >> $conflicts/$configName.configErrors
						validateFails=1
					fi
					if [[ -z "$samName" ]] ; then
						echo "### Sample name needs to be set $samName"
						echo "### Sample name needs to be set $samName" >> $conflicts/$configName.configErrors
						validateFails=1
					fi
					echo "### Sample with $arrayCount rows found for kit: $kitName, sample: $samName."
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
				#echo "adding $configLine to mergeArray"
				mergeArray[$count]=$configLine	
				((count++))
			fi
		else
			continue
		fi
	done
	if [ $sampleCount -lt 1 ] ; then
		echo "### Sample count needs to be at least 1. Found $sampleCount."
		echo "### Sample count needs to be at least 1. Found $sampleCount." >> $conflicts/$configName.configErrors
		validateFails=1
	else
		echo "### Found $sampleCount samples."
	fi

	### check if genome samples exist
	genomeSampleCount=`cat $configFile | grep ^SAMPLE | cut -d, -f4 | grep ^Genome | wc -l`
	if [ $genomeSampleCount -gt 0 ] ; then
		echo "### Genome sample(s) found: $genomeSampleCount"

		### if allele count is requested make sure first two is set up as a dna pair
		### and make sure third variable is RNA

		#check  that ALLELECOUNT variable is set
		#alleleCount=`cat $configFile | grep "^ALLELECOUNT=" | cut -d= -f2 | head -1 | tr -d [:space:]`
		#if [[ "$alleleCount" != "yes" && "$alleleCount" != "no" ]] ; then
		#	echo "### Allele count option ALLELECOUNT needs to be yes or no: $alleleCount"
		#	echo "### Allele count option ALLELECOUNT needs to be yes or no: $alleleCount" >> $conflicts/$configName.configErrors
		#	validateFails=1
		#fi
		# if alleleCount is yes we have to make sure alleleCount first two are dnapair and third is RNA
		if [ "$alleleCount" = "yes" ] ; then
			echo "### Allele count is requested. Checking if TRIPLET4ALLELECOUNT is set"
			tripletCount=0
			for triplet in `cat $configFile | grep "^TRIPLET4ALLELECOUNT=" | cut -d= -f2`
			do
				((tripletCount++))
				triplet1=`echo $triplet | cut -d, -f1`
				triplet2=`echo $triplet | cut -d, -f2`
				triplet3=`echo $triplet | cut -d, -f3`
				triplet1Type=`cat $configFile | awk '/^SAMPLE=/' | awk 'BEGIN{FS=","} $2=="'"$pair1"'"' | cut -d, -f4`
				triplet2Type=`cat $configFile | awk '/^SAMPLE=/' | awk 'BEGIN{FS=","} $2=="'"$pair2"'"' | cut -d, -f4`
				triplet3Type=`cat $configFile | awk '/^SAMPLE=/' | awk 'BEGIN{FS=","} $2=="'"$pair3"'"' | cut -d, -f4`
				if [[ "$triplet1Type" != "Exome" || "$triplet2Type" != "Exome" ]] ; then
					echo "### Exome triplet1 or 2 used in TRIPLET4ALLELECOUNT do not seem be exome: $triplet1Type, $triplet2Type"
					echo "### Exome triplet1 or 2 used in TRIPLET4ALLELECOUNT do not seem be exome: $triplet1Type, $triplet2Type" >> $conflicts/$configName.configErrors
					validateFails=1
				fi
				if [ "$triplet3Type" != "RNA" ] ; then
					echo "### RNA triplet3 used in TRIPLET4ALLELECOUNT do not seem to be RNA: $triplet3Type"
					echo "### RNA triplet3 used in TRIPLET4ALLELECOUNT do not seem to be RNA: $triplet3Type" >> $conflicts/$configName.configErrors
					validateFails=1
				fi
			done	
			#if [ $tripletCount -eq 0 ] ; then
			#	echo "### You must define TRIPLET4ALLELECOUNT if you want alleleCount calculated. Counted $tripletCount lines for this"
			#	echo "### You must define TRIPLET4ALLELECOUNT if you want alleleCount calculated. Counted $tripletCount lines for this" >> $conflicts/$configName.configErrors
			#	validateFails=1
			#fi
		fi

		#check  that CIRCOS variable is set
		circos=`cat $configFile | grep "^CIRCOS=" | cut -d= -f2 | head -1 | tr -d [:space:]`
		if [[ "$circos" != "yes" && "$circos" != "no" ]] ; then
			echo "### Circos option CIRCOS needs to be yes or no: $circos"
			echo "### Circos option CIRCOS needs to be yes or no: $circos" >> $conflicts/$configName.configErrors
			validateFails=1
		fi
		# if circos is yes we have to make sure circos exome pair exists and theyre both exome
		if [ "$circos" = "yes" ] ; then
			echo "### Circos is requested. Checking if EXOMEPAIR4CIRCOS is set"
			#for exomePair in `cat $configFile | grep "^EXOMEPAIR4CIRCOS=" | cut -d= -f2 | tr -d [:space:]`
			exomePairCount=0
			for exomePair in `cat $configFile | grep "^EXOMEPAIR4CIRCOS=" | cut -d= -f2`
			do
				((exomePairCount++))
				pair1=`echo $exomePair | cut -d, -f1`
				pair2=`echo $exomePair | cut -d, -f2`
				pair1Type=`cat $configFile | awk '/^SAMPLE=/' | awk 'BEGIN{FS=","} $2=="'"$pair1"'"' | cut -d, -f4`
				pair2Type=`cat $configFile | awk '/^SAMPLE=/' | awk 'BEGIN{FS=","} $2=="'"$pair2"'"' | cut -d, -f4`
				if [[ "$pair1Type" != "Exome" || "$pair2Type" != "Exome" ]] ; then
					echo "### Exome pairs used in EXOMEPAIR4CIRCOS do not seem be exome: $pair1Type, $pair2Type"
					echo "### Exome pairs used in EXOMEPAIR4CIRCOS do not seem be exome: $pair1Type, $pair2Type" >> $conflicts/$configName.configErrors
					validateFails=1
				fi
			done	
			if [ $exomePairCount -eq 0 ] ; then
				echo "### You must define EXOMEPAIR4CIRCOS if you want circos plot. Counted $exomePairCount lines for this"
				echo "### You must define EXOMEPAIR4CIRCOS if you want circos plot. Counted $exomePairCount lines for this" >> $conflicts/$configName.configErrors
				validateFails=1
			fi
		fi
	fi
	### validate if RNA sample exists TOPHATGTF, USEMASK vars are defined
	rnaSampleCount=`cat $configFile | grep ^SAMPLE | cut -d, -f4 | grep ^RNA | wc -l`
	if [ $rnaSampleCount -gt 0 ] ; then
		echo "### RNA sample(s) found: $rnaSampleCount"
		tophatGTF=`cat $configFile | grep "^TOPHATGTF=" | cut -d= -f2 | head -1 | tr -d [:space:]`
		if [[ "$tophatGTF" != "yes" && "$tophatGTF" != "no" ]] ; then
			echo "### Tophat GTF option TOPHATGTF needs to be yes or no: $tophatGTF"
			echo "### Tophat GTF option TOPHATGTF needs to be yes or no: $tophatGTF" >> $conflicts/$configName.configErrors
			validateFails=1
		fi
		clUseGTF=`cat $configFile | grep "^CUFFLINKUSEGTF=" | cut -d= -f2 | head -1 | tr -d [:space:]`
		if [[ "$clUseGTF" != "yes" && "$clUseGTF" != "no" ]] ; then
			echo "### Cufflink use GTF option CUFFLINKUSEGTF needs to be yes or no: $clUseGTF"
			echo "### Cufflink use GTF option CUFFLINKUSEGTF needs to be yes or no: $clUseGTF" >> $conflicts/$configName.configErrors
			validateFails=1
		fi
		clUseMASK=`cat $configFile | grep "^CUFFLINKUSEMASK=" | cut -d= -f2 | head -1 | tr -d [:space:]`
		if [[ "$clUseMASK" != "yes" && "$clUseMASK" != "no" ]] ; then
			echo "### Cufflink use MASK option CUFFLINKUSEMASK needs to be yes or no: $clUseMASK"
			echo "### Cufflink use MASK option CUFFLINKUSEMASK needs to be yes or no: $clUseMASK" >> $conflicts/$configName.configErrors
			validateFails=1
		fi
	
	fi

	if [ $validateFails -eq 1 ] ; then
		echo "### Config file $configName did not validate for one or more of the reasons above!!!"	
		echo "### Config file $configName did not validate for one or more of the reasons above!!!" >> $conflicts/$configName.configErrors
		mv $configFile $dbFail	
		#if [ ! -e $conflicts/$configName.configErrorSent ] ; then 
			echo "### Error email now sending to $email."
			#echo "There were errors in your config file: $configName. You should correct these errors." | mail -s "central pipeline: errors in config file" mrussell@tgen.org $email
			cat $conflicts/$configName.configErrors | mail -s "central pipeline: errors in config file $configName" mrussell@tgen.org $email
		#	touch $conflicts/$configName.configErrorSent
		#else
		#	echo "### Error email already sent."
		#fi
	else
		echo "### Config file $configName is good."
		echo "### Config good email now sending to $email."
		echo "Your config file $configName has validated, and the pipeline will now start. Much success!" | mail -s "central pipeline: config file validated $configName" mrussell@tgen.org $email
		mv $configFile $dbGood
	fi
	echo "### Done with config file: $configFile"
	echo ""
done
time=`date +%d-%m-%Y-%H-%M`
echo "Ended $0 at $time"
