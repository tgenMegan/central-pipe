#collectFastqDropbox gets this text file, 
#once done move to collectFastqDropboxUsed
#this script will be responsible for kicking off conversion script

collectFQdropBox="/scratch/mrussell/centralPipe/collectFQdropBox"
collectFQdbUsed="/scratch/mrussell/centralPipe/collectFQdbUsed"
collectFQdbFail="/scratch/mrussell/centralPipe/collectFQdbFail"
CA="/scratch/mrussell/centralPipe/conversionArea"
for fqList in `find $collectFQdropBox -name *FastqList.csv`
do #for all of the files in the dropbox
	runPar=${fqList/FastqList.csv/RunParameters.csv}
	if [ ! -e $runPar ] ; then
		echo "RunParameters.csv file doesn't exist"
		echo "Exiting..."
		exit
	fi
	#PIPELINE=`cat $runPar | cut -d, -f14`
	#if [[ $PIPELINE == Pegasus* ]] ; then
	#	CA="/scratch/mrussell/centralPipe/conversionAreaPegasus"
	#fi
	pedFile=${fqList/FastqList.csv/PEDvalues.tsv}
        if [ ! -e $pedFile ] ; then
                echo "$pedFile file doesn't exist"
                echo "This must not be a family study"
	else
		echo "$pedFile does exist"
        	echo "Must be a family study"
		dos2unix $pedFile
		CA="/scratch/mrussell/centralPipe/familyConversionArea"
		cat $pedFile | tr -d '\013' > $pedFile.tmp
        	tr '\r' '\n' < $pedFile.tmp | sed 's/"//g' > $pedFile
        	rm $pedFile.tmp
	fi
	echo "### fqList file is $fqList"
	echo "### runPar file is $runPar"
	if [ -e $runPar.inUse ] ; then
		echo "### This run parameters file is alread in use..."
		continue
	else
		touch $runPar.inUse
	fi
	dos2unix $fqList
	cat $fqList | tr -d '\013' > $fqList.tmp 
	tr '\r' '\n' < $fqList.tmp | sed 's/"//g' > $fqList
	rm $fqList.tmp
	dos2unix $runPar
	cat $runPar | tr -d '\013' > $runPar.tmp 
	tr '\r' '\n' < $runPar.tmp | sed 's/"//g' > $runPar
	rm $runPar.tmp
	email=`cat $runPar | cut -d, -f1`
	echo "### Email found in run par file: $email"


	cpFails=0
	for line in `cat $fqList`
	do #for each line in fqList file
		scratchLoc1=`echo $line | cut -d, -f2`"_R1_001.fastq.gz"
		scratchLoc2=`echo $line | cut -d, -f2`"_R2_001.fastq.gz"
		scratchPat1=`dirname $scratchLoc1`
		scratchPat2=`dirname $scratchLoc2`
		isilonLoc1=`echo $line | cut -d, -f3`"_R1_001.fastq.gz"
		isilonLoc2=`echo $line | cut -d, -f3`"_R2_001.fastq.gz"
		echo "### scratch: $scratchLoc1"
		echo "### isilon : $isilonLoc1"
		if [ -e $scratchLoc1 ] ; then
			echo "### Already exists on scratch. No worries..."
			touch $scratchLoc1
		else
			echo "### Not on scratch, bring from Isilon!"
			if [ -e $isilonLoc1 ] ; then
				echo "### Found on Isilon, will now copy..."
				if [ ! -d $scratchPat1 ] ; then
					mkdir -p $scratchPat1
				fi
				rsync $isilonLoc1 $scratchLoc1
				if [ $? -ne 0 ] ; then
					echo "### Copy failed."
					((cpFails++))
				fi	
			else
				echo "### Not found Isilon, this is bad!"
				((cpFails++))
			fi
		fi
		if [ -e $scratchLoc2 ] ; then
			echo "### Already exists on scratch. No worries..."
			touch $scratchLoc2
		else
			echo "### Not on scratch, bring from Isilon!"
			if [ -e $isilonLoc2 ] ; then
				echo "### Found on Isilon, will now copy..."
				if [ ! -d $scratchPat2 ] ; then
					mkdir -p $scratchPat2
				fi
				rsync $isilonLoc2 $scratchLoc2
				if [ $? -ne 0 ] ; then
					echo "### Copy failed."
					((cpFails++))
				fi	
			else
				echo "### Not found Isilon, this is bad!"
				((cpFails++))
			fi
		fi

	done #end for each line in fqList file
	if [ $cpFails -eq 0 ] ; then
		echo "### No failures..."
		#copying to conversion area to make config file
		cp $runPar ${CA}/
		cp $fqList ${CA}/
		#done, so moving them out of dropbox
		mv $runPar $collectFQdbUsed
		mv $fqList $collectFQdbUsed
		if [ ! -e $pedFile ] ; then
      	        	echo "$pedFile file doesn't exist"
                	echo "This must not be a family study"
        	else
                	cp $pedFile ${CA}/
                	mv $pedFile $collectFQdbUsed
        	fi

	else
		echo "### A copy failed or file wasnt found."
		echo "### Preparing mail to be sent..."	
		echo "### Central collect fastq script ran into problems. Either file doesn't exist on Isilon or copy process failed" > ~/mailtmp-$$.txt
		echo "" >> ~/mailtmp-$$.txt
		cat $fqList >> ~/mailtmp-$$.txt
		echo "" >> ~/mailtmp-$$.txt
		mail -s "central pipeline: Collect fastq script failed" "mrussell@tgen.org" < ~/mailtmp-$$.txt
		mail -s "central pipeline: Collect fastq script failed" "$email" < ~/mailtmp-$$.txt
		rm ~/mailtmp-$$.txt
		mv $runPar $collectFQdbFail
		mv $fqList $collectFQdbFail
		mv $pedFile $collectFQdbFail
		#email people to tell them their fastqs are missing
	fi
	rm $runPar.inUse
done #end for all of the files in the dropbox
