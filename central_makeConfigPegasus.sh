DB="/scratch/mrussell/centralPipe/dropBox"
CA="/scratch/mrussell/centralPipe/conversionArea"
CAU="/scratch/mrussell/centralPipe/conversionAreaUsed"
time=`date +%d-%m-%Y-%H-%M`
echo "Starting $0 at $time"
for fqList in `find ${CA} -name *FastqList.csv`
do #for all of the files in conversion area
	runPar=${fqList/FastqList.csv/RunParameters.csv}
	if [ ! -e $runPar ] ; then
		echo "RunParameters.csv file doesn't exist"
		echo "Exiting..."
		exit
	fi
	echo "### fqList file is $fqList"
	echo "### runPar file is $runPar"
	if [ -e $runPar.inUse ] ; then
		echo "### This run parameters file is alread in use..."
		continue
	else
		touch $runPar.inUse
	fi

	projName=`cat $runPar | cut -d, -f2`

	EMAIL=`cat $runPar | cut -d, -f1`
	EMAIL=${EMAIL/:/,}
	PROJECT=`cat $runPar | cut -d, -f2`
	RECIPE=`cat $runPar | cut -d, -f3`
	DEBIT=`cat $runPar | cut -d, -f4`
	RESULTS=`cat $runPar | cut -d, -f5`
	SAVERECIPE=`cat $runPar | cut -d, -f6`
	HOLDCONFIG=`cat $runPar | cut -d, -f13`
	PIPELINE=`cat $runPar | cut -d, -f14`
        SAVEFORMAT=`cat $runPar | cut -d, -f15`
        DATABASESAVE=`cat $runPar | cut -d, -f16`
	
	genNor=`cat $runPar | cut -d, -f7`
	genTum=`cat $runPar | cut -d, -f8`
	exoNor=`cat $runPar | cut -d, -f9`
	exoTum=`cat $runPar | cut -d, -f10`
	rnaNor=`cat $runPar | cut -d, -f11`
	rnaTum=`cat $runPar | cut -d, -f12`

	echo "EMAIL=$EMAIL" > ${CA}/$projName.config
	echo "PROJECT=$PROJECT" >> ${CA}/$projName.config
	echo "PIPELINE=$PIPELINE" >> ${CA}/$projName.config
	echo "RECIPE=$RECIPE" >> ${CA}/$projName.config
	echo "DEBIT=$DEBIT" >> ${CA}/$projName.config
	echo "RESULTS=$RESULTS" >> ${CA}/$projName.config
	echo "SAVERECIPE=$SAVERECIPE" >> ${CA}/$projName.config
	echo "HOLDCONFIG=$HOLDCONFIG" >> ${CA}/$projName.config
	if [ "$SAVEFORMAT" == "simple" ] ; then
                echo "SAVESIMPLE=Yes" >> ${CA}/$projName.config
        fi
        if [ "$DATABASESAVE" == "Yes" ] ; then
                echo "REPORT=/ngd-data/reports/" >> ${CA}/$projName.config
        fi

	if [ "$HOLDCONFIG" == "Yes" ] ; then
		chmod 777 ${CA}/$projName.config
	fi


	#this is where you would count how many different normals and tumors are there and build some 
	#sort of logic to loop through them to print out multiple DNAPAIR lines

	#genome normal section
	if [ "$genNor" == "Ready" ] ; then
		#genNorSampleName=`cat $fqList | awk 'BEGIN{FS=","} $7=="Genome" && $9=="Constitutional" {print $5}' | head -1`
		genNorSampleList=`cat $fqList | awk 'BEGIN{FS=","} $7=="Genome" && $9=="Constitutional" {print $5}' | sort | uniq | xargs`
		echo "### gen nor sample name: $genNorSampleName"
	fi

	#genome tumor  section
	if [ "$genTum" == "Ready" ] ; then
		#genTumSampleName=`cat $fqList | awk 'BEGIN{FS=","} $7=="Genome" && $9=="Tumor" {print $5}' | head -1`
		genTumSampleList=`cat $fqList | awk 'BEGIN{FS=","} $7=="Genome" && $9=="Tumor" {print $5}' | sort | uniq | xargs`
		echo "### gen tum sample name: $genTumSampleName"
	fi
	#print out genome pairs
	if [[ "$genTum" == "Ready" &&  "$genNor" == "Ready" ]] ; then
		#echo "DNAPAIR=$genNorSampleName,$genTumSampleName" >> ${CA}/$projName.config
		for eachNor in `echo $genNorSampleList`
		do
			for eachTum in `echo $genTumSampleList`
			do
				echo "DNAPAIR=$eachNor,$eachTum" >> ${CA}/$projName.config
			done
		done
		genJirSetName="${PROJECT}_Genome_JIRSET"
	        genJirSet=`echo "${genNorSampleList// /,},${genTumSampleList// /,};${genJirSetName}"`
        	echo "JIRSET=$genJirSet" >> ${CA}/$projName.config

	fi
	#exome normal section
	if [ "$exoNor" == "Ready" ] ; then
		#exoNorSampleName=`cat $fqList | awk 'BEGIN{FS=","} $7=="Exome" && $9=="Constitutional" {print $5}' | head -1`
		exoNorSampleList=`cat $fqList | awk 'BEGIN{FS=","} $7=="Exome" && $9=="Constitutional" {print $5}' | sort | uniq | xargs`
		#echo "### exo nor sample name: $exoNorSampleName"
	fi

	#exome tumor  section
	if [ "$exoTum" == "Ready" ] ; then
		#exoTumSampleName=`cat $fqList | awk 'BEGIN{FS=","} $7=="Exome" && $9=="Tumor" {print $5}' | head -1`
		exoTumSampleList=`cat $fqList | awk 'BEGIN{FS=","} $7=="Exome" && $9=="Tumor" {print $5}' | sort | uniq | xargs`
	fi
	#print out exome pairs
	if [[ "$exoTum" == "Ready" &&  "$exoNor" == "Ready" ]] ; then
		#echo "DNAPAIR=$exoNorSampleName,$exoTumSampleName" >> ${CA}/$projName.config
		for eachNor in `echo $exoNorSampleList`
                do
                        for eachTum in `echo $exoTumSampleList`
                        do
                                echo "DNAPAIR=$eachNor,$eachTum" >> ${CA}/$projName.config
                        done
                done
		exoJirSetName="${PROJECT}_Exome_JIRSET"
	        exoJirSet=`echo "${exoNorSampleList// /,},${exoTumSampleList// /,};${exoJirSetName}"`
        	echo "JIRSET=$exoJirSet" >> ${CA}/$projName.config
	fi

	#rna section
	#RNA normal section
	if [ "$rnaNor" == "Ready" ] ; then
		#rnaNorSampleName=`cat $fqList | awk 'BEGIN{FS=","} $7=="RNA" && $9=="Constitutional" {print $5}' | head -1`
		rnaNorSampleList=`cat $fqList | awk 'BEGIN{FS=","} $7=="RNA" && $9=="Constitutional" {print $5}' | sort | uniq | xargs`
		#echo "### rna nor sample name: $rnaNorSampleName"
	fi

	#RNA tumor  section
	if [ "$rnaTum" == "Ready" ] ; then
		#rnaTumSampleName=`cat $fqList | awk 'BEGIN{FS=","} $7=="RNA" && $9=="Tumor" {print $5}' | head -1`
		rnaTumSampleList=`cat $fqList | awk 'BEGIN{FS=","} $7=="RNA" && $9=="Tumor" {print $5}' | sort | uniq | xargs`
		#echo "### rna tum sample name: $rnaTumSampleName"
	fi
	#print out RNA pairs
	if [[ "$rnaTum" == "Ready" &&  "$rnaNor" == "Ready" ]] ; then
		for eachNor in `echo $rnaNorSampleList`
                do
                        for eachTum in `echo $rnaTumSampleList`
                        do
                                echo "RNAPAIR=$eachNor,$eachTum" >> ${CA}/$projName.config
                        done
                done
		#echo "RNAPAIR=$rnaNorSampleName,$rnaTumSampleName" >> ${CA}/$projName.config
	fi

	#triplet for allele count section
	if [[ "$rnaTum" == "Ready" && "$exoTum" == "Ready" && "$exoNor" == "Ready" ]] ; then
	        for eachExoNor in `echo $exoNorSampleList`
                do
                        for eachExoTum in `echo $exoTumSampleList`
                        do
				#for dnaPairLine in `cat ${CA}/$projName.config | grep '^DNAPAIR='`
				#do
				#echo "### DNA pair line is $dnaPairLine"
				#exoNormal=`echo $dnaPairLine | cut -d= -f2 | cut -d, -f1`
				#exoTumor=`echo $dnaPairLine | cut -d= -f2 | cut -d, -f2`
				#matchExoTumor=`echo $eachExoTum | cut -d_ -f1-4`
				for eachRnaTum in `echo $rnaTumSampleList`
				do
					matchRnaTumor=`echo $eachRnaTum | cut -d_ -f1-4`
					matchExoTumor=`echo $eachExoTum | cut -d_ -f1-4`
					echo "TumorExome: $matchExoTumor"
					echo "RNA: $matchRnaTumor"
					if [ "$matchRnaTumor" == "$matchExoTumor" ] ; then
						echo "TRIPLET4ALLELECOUNT=$eachExoNor,$eachExoTum,$eachRnaTum" >> ${CA}/$projName.config	
					fi
				done	
			done
		done
		#rnaTumSampleName=`cat $fqList | awk 'BEGIN{FS=","} $7=="RNA" && $9=="Tumor" {print $5}' | head -1`
		#echo "TRIPLET4ALLELECOUNT=$exoNorSampleName,$exoTumSampleName,$rnaTumSampleName" >> ${CA}/$projName.config
	fi
	
	echo "=START" >> ${CA}/$projName.config
	for eachSample in `cat $fqList | awk 'BEGIN{FS=","} {print $5}' | sort | uniq`
	do
		eachSampleName=`echo ${eachSample} | cut -d_ -f1-7`
		kitName=`cat $fqList | awk 'BEGIN{FS=","} $5=="'"$eachSample"'"  {print $4}' | head -1`
		assayID=`cat $fqList | awk 'BEGIN{FS=","} $5=="'"$eachSample"'"  {print $7}' | head -1`
		#libraID=`cat $fqList | awk 'BEGIN{FS=","} $5=="'"$eachSample"'"  {print $8}' | head -1`
		#echo "SAMPLE=$kitName,$eachSample,$assayID,$libraID" >> ${CA}/$projName.config
		echo "SAMPLE=$kitName,$eachSampleName,$assayID" >> ${CA}/$projName.config
		for eachRead in `cat $fqList | awk 'BEGIN{FS=","} $5=="'"$eachSample"'" {print $1"_"$8","$2}'`
		do
			echo "FQ=$eachRead""_R1_001.fastq.gz" >> ${CA}/$projName.config
		done
	done
	echo "=END" >> ${CA}/$projName.config
	mv ${CA}/$projName.config ${DB}/
	mv $fqList ${CAU}
	mv $runPar ${CAU}
	rm $runPar.inUse
done
time=`date +%d-%m-%Y-%H-%M`
echo "Ending $0 at $time"
