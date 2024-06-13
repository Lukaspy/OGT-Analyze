#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later


//Macro Recolor_Traces()
//	RecolorTraces()
//EndMacro

Macro Quick_Color_Spectrum()
	QuickColorSpectrum(WinName(0,1))
EndMacro

//Create a 3d graph of 1D waves selected in Data browser
Macro plot_Responses_3D()
	plotResponses3D()
EndMacro

// Color Graph traces automatically
Function QuickColorSpectrum(graphName)                            // colors traces with 12 different colors
	String graphName
    String Traces    = TraceNameList(graphName,";",1)               // get all the traces from the graph
    Variable Items   = ItemsInList(Traces)                   // count the traces
    Make/FREE/N=(11,3) colors = {{65280,0,0}, {65280,43520,0}, {0,65280,0}, {0,52224,0}, {0,65280,65280}, {0,43520,65280}, {0,15872,65280}, {65280,16384,55552}, {36864,14592,58880}, {0,0,0},{26112,26112,26112}}
    Variable i
    for (i = 0; i <DimSize(colors,1); i += 1)
    	ModifyGraph rgb($StringFromList(i,Traces))=(colors[0][i],colors[1][i],colors[2][i])      // set new color offset
    endfor
End



//modifed From multiloader
Function RecolorAirTraces() 
	String ctrlName
	
	String graphName = WinName(0, 1)	//Fidns the name of the active graph
	if (strlen(graphName) == 0)	//Makes sure the graph exists
		return -1
	endif
	
	String tnl = TraceNameList( "", ";", 1 )	//Gets a list of all the traces
	Variable numTraces = ItemsInList(tnl)	//Finds the number of traces
	if (numTraces <= 0)	//Makes sure there are traces
		return -1
	endif

	Variable red, green, blue
	Variable i, index
	for(i=0; i<numTraces; i+=1)	//Loops for every trace on the graph
		
		if (strsearch(stringfromList(i, tnl), "ial",0) != -1)
			red = 65535
			green = 0
			blue = 0
		elseif (strsearch(stringfromList(i, tnl), "fin", 0) != -1)
			blue = 65535
			red = 0
			green = 0
		elseif (strsearch(stringfromList(i, tnl), "lab", 0) != -1)
			red = 65535
			green = 43690
			blue = 0
		endif
		ModifyGraph rgb[i]=(red, green, blue)	//Sets the color of a trace
	endfor
	ModifyGraph mirror=1
End

// Load all csvs in the specificed directory path
// creates 3 waves from the collected OGT data (time, ogt response, and the light pulse waveform)
// Returns list of generated response waves on success, -1 or error
Function/S loadFilesFromDir(userPath, [loadTimeFlag, loadPulseFlag, normalizeFlag, offsetFlag, killUnnorms])
	String userPath
	variable loadTimeFlag, loadPulseFlag, normalizeFlag, offsetFlag, killUnnorms
	String responseList	= ""

	variable i = 0
	string baseWname, fname
		
	
	//Store the selected folder as an Igor path
	newpath/O loadPath userPath
	
	string filelist = indexedfile(loadPath, -1, ".csv")
	
	//Process list of files
	do
		//Store current filename
		fname = stringfromlist(i, filelist)
		
		//Remove .csv from the file name
		baseWname = fname[0,strlen(fname)-5]
		
		//Create wave name same as file
		wave w = $baseWname + "_response"
		
		//If wave does not exist create it
		if (!waveexists(w))
			//Load csv data as 3 waves (time, measured response, and pulse
			LoadWave/J/D/A/P=loadPath/K=1 stringfromlist(i, filelist)
			
			//rename waves 
			
			//Delete time wave if not needed
			if (loadTimeFlag != 1)
				killWaves $"wave0"
			else
				String timeWave = baseWname + "_time"
				rename wave0 $timeWave
			endif
			
			String responseWave = baseWname + "_response"
			rename wave1  $responseWave
			
			//Delete pulse wave if not needed
			if (loadPulseFlag != 1)
				killWaves $"wave2"
			else 
				String pulseWave = baseWname + "_pulse"
				rename wave2 $pulseWave
			endif	
			//Add wavename to responseList
			responseList = responseList + responseWave + ";"
			
			//Print name of loaded file
			print "Loaded " + fname
			
					//Remove offset if requested
			if (offsetFlag == 1)
				variable offsetPoint = 100
				removeOffset($responseWave, offsetPoint)
			endif
		
			//normalize Data if requested
			if (normalizeFlag == 1)
				String normWave = responseWave + "_zeroed"
				normalizeData($normWave)
			endif
			
			if (killUnnorms == 1)
				killWaves $responseWave
				String zeroedWave = responseWave + "_zeroed"
				killWaves $zeroedWave
			endif
		else
			//File is already loaded
			print fname + " was already loaded, wave exists."
			responseWave = baseWname + "_response"
			responseList = responseList + responseWave + ";"
		endif
		i += 1	
	while (i < itemsInList(filelist))
	return responseList
End

//Recursively load all csvs from a base directory
Function loadFilesFromDirRecursively([userPath, loadTimeFlag, loadPulseFlag, singlePulseFlag, triplePulseFlag, normalizeFlag, offsetFlag, killUnnorms])
	String userPath
	variable loadTimeFlag, loadPulseFlag, singlePulseFlag, triplePulseFlag, normalizeFlag, offsetFlag, killUnnorms
	String responseList	= ""

	variable i = 0
	string baseWname, fname
	
	String filelist
	String dirList
	
	//If no basePath specified ask user for it
	if (ParamIsDefault(userPath))
		getfilefolderInfo/D
		
		if (V_flag == -1)
			return 1
		endif
		
		userPath = S_path
		newpath/O loadPath S_path
		filelist = indexedFile(loadPath, -1, ".csv")
		dirList = indexedDir(loadPath, -1, 0)

	else
		newpath/O loadPath userPath
		filelist = indexedFile(loadPath, -1, ".csv")
		dirList = indexedDir(loadPath, -1, 0)
	endif
	
	//Check if basePath is a leaf (contains no more dirs, only csvs to process)
	if ((itemsinList(filelist) != 0) && (itemsinList(dirList) == 0))
		loadFilesFromDir(userPath, loadTimeFlag = loadTimeFlag, loadPulseFlag = loadPulseFlag, normalizeFlag = normalizeFlag, offsetFlag = offsetFlag, killUnnorms=killUnnorms)
	else
		string nextPath
		for (i = 0; i < itemsInList(dirList); i++)
			if (GrepString(stringfromList(i, dirList), "single") && singlePulseFlag == 1)
				nextPath = userPath + stringFromList(i,dirList) + ":"
				loadFilesFromDir(nextPath, loadTimeFlag = loadTimeFlag, loadPulseFlag = loadPulseFlag, normalizeFlag = normalizeFlag, offsetFlag = offsetFlag, killUnnorms=killUnnorms)
			elseif (GrepString(stringFromList(i,dirList), "triple") && triplePulseFlag == 1)
				nextPath = userPath + stringFromList(i,dirList) + ":"
				loadFilesFromDir(nextPath, loadTimeFlag = loadTimeFlag, loadPulseFlag = loadPulseFlag, offsetFlag = offsetFlag, normalizeFlag = normalizeFlag, killUnnorms=killUnnorms)
			elseif (GrepString(stringFromList(i,dirList), "triple") && triplePulseFlag != 1)
				continue
			else
				nextPath = userPath + stringFromList(i,dirList) + ":"
				loadFilesFromDirRecursively(userPath = nextPath, loadTimeFlag = loadTimeFlag, loadPulseFlag = loadPulseFlag, singlePulseFlag = singlePulseFlag, triplePulseFlag = triplePulseFlag, offsetFlag = offsetFlag, normalizeFlag = normalizeFlag, killUnnorms=killUnnorms)
			endif
		endfor
		
	endif		
End
//Load the OGT responses from the given files, convolve them, and convert result to csv
Function convolveTwoResponses(userPath1, userPath2, displayFlag)
	String userPath1
	String userPath2
	variable displayFlag 
	
	//Verify files are csv
	//if (!stringmatch(userPath1[strlen(userPath1)-5, strlen(userPath1)], ".csv") || !stringmatch(userPath1[strlen(userPath1)-5, strlen(userPath1)], ".csv") )
	//	return -1
	//endif
	
	//Load both csv files
	String baseWaveName1 = userPath1[0, strlen(userPath1) - 5]
	//Extract filename from the full path
	String filename1 = baseWaveName1[strsearch(baseWaveName1, "\\", strlen(baseWaveName1), 3) + 1, strlen(baseWaveName1)]
	wave w1 = $filename1 + "_time"
	print filename1
	
	String baseWaveName2 = userPath2[0, strlen(userPath2) - 5]
	String filename2 = baseWaveName2[strsearch(baseWaveName2, "\\", strlen(baseWaveName2), 3) + 1, strlen(baseWaveName2)]
	wave w2 = $filename2+ "_time"
	
	if (!waveexists(w1) && !waveexists(w2))
		//Load csv data as 3 waves (time, measured response, and pulse
		LoadWave/J/D/A=wave/P=loadPath/K=0 userPath1
		LoadWave/J/D/A=wave/P=loadPath/K=0 userPath2
			
		//rename waves 
		rename wave0 $filename1 + "_time"
		rename wave1 $filename1 + "_response"
		rename wave2 $filename1 + "_pulse"
		
		rename wave3 $filename2 + "_time"
		rename wave4 $filename2 + "_response"
		rename wave5 $filename2 + "_pulse"
		
		
		
		//Print name of loaded file
		print "Loaded " + baseWaveName1
		print "Loaded " + baseWaveName2
	else
		//File is already loaded
		print "Files are already loaded, wave exists."
	endif		 
	
	//Get wave names to convolve
	String response1 = filename1 + "_response"
	String response2 = filename2 + "_response"
	
	//Perform the convolution, first duplicate response2 since it will be overwritten
	String outputFilename = "conv_" + filename1 + "_and_" + filename2
	
	Duplicate/O $response1, $outputFilename; DelayUpdate
	Convolve $response2, $outputFilename;DelayUpdate
	
	if (displayFlag == 1) 
		display $outputFilename
	endif
End

//imports all files in the given directory, convolves each with the initial air response, displays result when displayFlag == 1
Function convolveAirAndSampleDir([userPath, displayFlag, exportFlag, offsetFlag, offsetPoint, normalizeFlag])
	String userPath
	variable displayFlag
	variable exportFlag
	variable offsetFlag
	variable offsetPoint
	variable normalizeFlag
	
	String responseList
	String graphName
	
	//offset to the 100th data point if none is specified
	if (ParamIsDefault(offsetPoint))
		offsetPoint = 100
	endif
		
	if (ParamIsDefault(userPath))
		getfilefolderInfo/D
		responseList = loadFilesFromDir(S_path)
		userPath = S_path
		
	else
		 responseList = loadFilesFromDir(userPath)
	endif
	newPath/O loadPath userPath
	
	//Find the initial air response file
	String airResponse = ""
	variable i = 0
	do
		String currentResponse = stringfromList(i, responseList)
		//Check if filename contains air and initial, when found remove from list
		if (GrepString(currentResponse, "air") && GrepString(currentResponse, "in") && GrepString(currentResponse, "t"))
			airResponse = currentResponse
			
			//Normalize and zero if requested
			if (offsetFlag == 1)
				removeOffset($airResponse, offsetPoint)
		
				airResponse = airResponse + "_zeroed"
			endif
			
			if (normalizeFlag == 1)
				normalizeData($airResponse)
				airResponse = airResponse + "_norm"
			endif
			
			break
		endif
		i += 1
	while(i < itemsinList(responseList))	
	
	//Verify that the initial air response exists
	if (cmpstr(airResponse, "", 0) == 0)
		print "No initial air response found"
		return -1
	endif


	//Set window name
	if (displayFlag == 1)
		String baseGraphName = "airConvOut"
		graphName = baseGraphName
		i = 1
		do
			if (winType(graphName) == 1)
				graphName = baseGraphName + num2str(i) 
			endif
			i += 1
		while(winType(graphName) == 1)

	endif 
	
	//Perform the convolution for each file
	for (i = 0; i < itemsInList(responseList); i++)
		String currentWave = stringfromList(i, responseList)
		
		//Remove offset if requested
		if (offsetFlag == 1)
			removeOffset($currentWave, offsetPoint)
			//make the current wave point to the zeroed version
			currentWave = currentWave + "_zeroed"
		endif
		
		//normalize Data if requested
		if (normalizeFlag == 1)
			normalizeData($currentWave)
			//make current wave point to the normalized version
			currentWave = currentWave + "_norm"
		endif
		
		if (GrepString(currentWave, "conv"))
			continue
		endif
		
		String outputFilename = "conv_" + airResponse + "_and_" + currentWave
		Duplicate/O $airResponse, $outputFilename; DelayUpdate
		Convolve $airResponse, $outputFileName;DelayUpdate
		if (displayFlag == 1)
			if (i == 0)
				display/N=$graphName $outputFilename
			else
				appendtoGraph/W=$graphName $outputFilename
			endif
		endif
		
		if (exportFlag == 1)
			Save/J/M="\r\n"/DLIM=","/W/P=loadPath $outputFilename as outputFilename + ".csv"
		endif
	endfor
	
	if (displayFlag == 1)
		quickColorSpectrum(graphName)
		Legend/C/N=text0/W=$graphName
	endif
	
	
	
End

Function convolveAirAndSampleRecursively([basePath, displayFlag, exportFlag, offsetFlag, normalizeFlag])
	String basePath
	variable displayFlag
	variable exportFlag
	variable offsetFlag
	variable normalizeFlag
	String filelist
	String dirList
	
	//If no basePath specified ask user for it
	if (ParamIsDefault(basePath))
		getfilefolderInfo/D
		basePath = S_path
		newpath/O loadPath S_path
		filelist = indexedFile(loadPath, -1, ".csv")
		dirList = indexedDir(loadPath, -1, 0)

	else
		newpath/O loadPath basePath
		filelist = indexedFile(loadPath, -1, ".csv")
		dirList = indexedDir(loadPath, -1, 0)
	endif
	
	//Check if basePath is a leaf (contains no more dirs, only csvs to process)
	if ((itemsinList(filelist) != 0) && (itemsinList(dirList) == 0))
		convolveAirandSampleDir(userPath = basePath, displayFlag = displayFlag, exportFlag = exportFlag, offsetFlag = offsetFlag, normalizeFlag = normalizeFlag)
	else
		variable i
		for (i = 0; i < itemsInList(dirList); i++)
			if (GrepString(stringfromList(i, dirList), "single"))
				string newPath = basePath + stringFromList(i,dirList) + ":"
				convolveAirAndSampleRecursively(basePath = newPath, displayFlag = displayFlag, exportFlag = exportFlag, offsetFlag = offsetFlag, normalizeFlag = normalizeFlag)
			elseif (GrepString(stringFromList(i,dirList), "triple"))
				continue
			else
				newPath = basePath + stringFromList(i,dirList) + ":"
				convolveAirAndSampleRecursively(basePath = newPath, displayFlag = displayFlag, exportFlag = exportFlag, offsetFlag = offsetFlag, normalizeFlag = normalizeFlag)
			endif
		endfor
		
	endif
	
End


//Remove any dc offset from input wave
//Where offsetPoint is the desired wave data point to get the offset value from
Function/WAVE removeOffset(waveToOffset, offsetPoint)
	wave waveToOffset
	variable offsetPoint

	variable offsetAmount = sum(waveToOffset, pnt2x(waveToOffset,1), pnt2x(waveToOffset,offsetPoint)) / offsetPoint
	String waveToOffsetName = nameOfWave(waveToOffset)
	String outputWaveName = waveToOffsetName + "_zeroed"
	duplicate/O waveToOffset $outputWaveName
	wave outputWave = $outputWaveName

	outputWave = waveToOffset - offsetAmount

	return $outputWaveName
End

//Remove ethanol baseline (ie subtract one wave from another and create new wave)
Function/WAVE removeBaseline(waveToBaseline, baseline)
	wave waveToBaseline
	wave baseline
	
	string waveToBaselineName = nameOfWave(waveToBaseline)

	string outputWaveName = waveToBaselineName + "_rmBaseline"
	
	duplicate/O waveToBaseline $outputWaveName
	
	wave outputWave = $outputWaveName
	
	outputWave -= baseline
	
	return $outputWaveName	
End

//Remove baseline for all waves matching a filter
Function removeBaselineMany(waveFilter, baselineWave)
	string waveFilter
	wave baselineWave
	
	
	string wavesToBaseline = waveList(waveFilter, ";", "")
	
	print "found " + num2str(itemsInList(wavesToBaseline)) + " waves."
	
	string alertMsg
	if (itemsInList(wavesToBaseline) > 20)
		alertMsg = "found " + num2str(itemsInList(wavesToBaseline)) + " waves.\n Continue?"
	else
		alertMsg = "The following waves were found. Continue?\n" + wavesToBaseline
	endif
	DoAlert 1, alertMsg
	
	//exit if user clicks no
	if (V_flag == 2)
		return 1
	endif	
	
	variable i
	for (i = 0; i < itemsinList(wavesToBaseline); i++)	
		string currentWave = stringFromList(i, wavesToBaseline)
		removeBaseline($currentWave, baselineWave)
	endfor
	
End

//Normalize a wave to a max value of 1 using the max value of the wave
Function/WAVE normalizeData(waveToNormalize)
	wave waveToNormalize
	
	string waveToNormalizeName = nameOfWave(waveToNormalize)
	variable maxValue = waveMax(waveToNormalize)
	
	string outputWaveName = waveToNormalizeName + "_norm"
	duplicate /O  waveToNormalize $outputWaveName
	wave normalized = $outputWaveName
	normalized = waveToNormalize/maxValue
	
	return $outputWaveName
End

//Normalize all waves matching a filter
Function normalizeDataMany(waveFilter)
	string waveFilter
	
	string wavesToNormalize = waveList(waveFilter, ";", "")
	
	print "found " + num2str(itemsInList(wavesToNormalize)) + " waves."
	
	string alertMsg
	if (itemsInList(wavesToNormalize) > 20)
		alertMsg = "found " + num2str(itemsInList(wavesToNormalize)) + " waves.\n Continue?"
	else
		alertMsg = "The following waves were found. Continue?\n" + wavesToNormalize
	endif
	
	DoAlert 1, alertMsg
	
	//exit if user clicks no
	if (V_flag == 2)
		return 1
	endif	
	
	variable i
	for (i=0; i < itemsInList(wavesToNormalize); i++)
		string currentWaveName = stringfromList(i, wavesToNormalize)
		wave currentWave = $currentWaveName
		normalizeData(currentWave)
	endfor
End

//Normalize to the user selected point
Function normalizeToPoint(waveToNormalize, pointToUse)
	wave waveToNormalize
	variable pointToUse
	
	string waveToNormalizeName = nameOfWave(waveToNormalize)
	variable maxValue = waveToNormalize[pointToUse]
	
	string outputWaveName = waveToNormalizeName + "_norm"
	duplicate /O  waveToNormalize $outputWaveName
	wave normalized = $outputWaveName
	normalized = waveToNormalize/maxValue
	
	appendToGraph normalized
End

//Multipulse convolution
//Convolve pulse 1&2, 2&3, 3&4 for a given filter
//Assumes that waves are named *_1*, *_2*, ... for each pulse train
Function multiPulseConvolution(waveFilter, [normalizeFlag])
	string waveFilter
	//Normalize after convolution
	variable normalizeFlag
	
	//number of pulse trains to convolve
	variable numPulses = 4
	
	string wavesToConvolve = waveList(waveFilter, ";", "")
	
	print "found: \n" + wavesToConvolve
	
	string alertMsg = "The following waves were found. Continue?\n" + wavesToConvolve
	DoAlert 1, alertMsg
	
	//exit if user clicks no
	if (V_flag == 2)
		return 1
	endif
	
	variable i
	variable numWaves = itemsinlist(wavesToConvolve)
	for (i = 1; i < numPulses; i++)
		
		
		//get waves to convolve 
		string firstWaveName
		string secondWaveName
		
		variable j
		for (j = 0; j < numWaves; j++)
			string currentWaveName = stringFromList(j, wavesToConvolve)
			
			//Check if current wave is the first target wave
			string waveFilter1 = "*_" + num2str(i) + "_res*"
			if (stringMatch(currentWaveName, waveFilter1))
				firstWaveName = currentWaveName		
			endif
			
			//Check if current wave is second target wave
			string waveFilter2 = "*_" + num2str(i+1) + "_res*"
			if (stringMatch(currentWaveName, waveFilter2))
				secondWaveName = currentWaveName				
			endif
			
			
		endfor
		
		Wave firstWave = $firstWaveName
		Wave secondWave = $secondWaveName
		//check if first row is NaN (had a column name)
		if (numtype(firstWave[0]) == 2)
			firstWave[0] = 0
		endif
		if (numtype(secondWave[0]) == 2)
			secondWave[0] = 0
		endif
		
		//determine output wave name
		string outputName = firstWaveName + "_and_" + secondWaveName + "_conv"

		//do convolution
		Duplicate/O $firstWaveName, $outputName;DelayUpdate
		Convolve $secondWaveName, $outputName;DelayUpdate
		
		if (normalizeFlag == 1)
			normalizeData($outputName)
		endif
		
	endfor
	
End

//Multipulse air convolution
//Convolve wave matching the input filter with the air response
Function multipulseConvolutionAir(waveFilter, airWave, [normalizeFlag])
	string waveFilter
	wave airWave
	variable normalizeFlag
	
	string wavesToConvolve = waveList(waveFilter, ";", "")
	
	print "found " + num2str(itemsInList(wavesToConvolve)) + " waves."
	
	string alertMsg
	if (itemsInList(wavesToConvolve) > 20)
		alertMsg = "found " + num2str(itemsInList(wavesToConvolve)) + " waves.\n Continue?"
	else
		alertMsg = "The following waves were found. Continue?\n" + wavesToConvolve
	endif
	
	DoAlert 1, alertMsg
	
	//exit if user clicks no
	if (V_flag == 2)
		return 1
	endif	
	
	//check if first row is NaN (had a column name)
	if (numtype(airWave[0]) == 2)
		airWave[0] = 0
	endif
		
	variable i
	for (i = 0; i < itemsinList(wavesToConvolve); i++)	
		string currentWaveName = stringFromList(i, wavesToConvolve)
		
		//check if first row is NaN (had a column name)
		wave currentWave = $currentWaveName
		if (numtype(currentWave[0]) == 2)
			currentWave[0] = 0
		endif
		
		//determine output wave name
		string outputName = currentWaveName + "_airconv"

		//do convolution
		Duplicate/O $currentWaveName, $outputName;DelayUpdate
		Convolve airWave, $outputName;DelayUpdate
		
		if (normalizeFlag == 1)
			normalizeData($outputName)
		endif
		
	endfor
End

//Differentiate the input wave
Function differentiateWave(inputWave)
	wave inputWave
	
	string inputWaveName = nameOfWave(inputWave)
	string outputWaveName = inputWaveName + "_dif"
	
	Differentiate inputWave /D=$outputWaveName;DelayUpdate
End

//Differentiate all waves matching the filter
Function differentiateManyWaves(waveFilter)
	string waveFilter
	
	string wavesToDiff = waveList(waveFilter, ";", "")
	
	print "found " + num2str(itemsInList(wavesToDiff)) + " waves."
	
	string alertMsg
	if (itemsInList(wavesToDiff) > 20)
		alertMsg = "found " + num2str(itemsInList(wavesToDiff)) + " waves.\n Continue?"
	else
		alertMsg = "The following waves were found. Continue?\n" + wavesToDiff
	endif
	DoAlert 1, alertMsg
	
	//exit if user clicks no
	if (V_flag == 2)
		return 1
	endif
	
	variable i
	for (i = 0; i < itemsInList(wavesToDiff); i++)
		wave currentWave = $stringFromList(i, wavesToDiff)
		differentiateWave(currentWave)
	endfor
	
End

//Generate fit waves from exported batch table for graphing fit parameters
Function generateFitWaves(nameWave, resultWave)
	wave/T nameWave
	wave resultWave
	
	//Store what pulse we are on
	variable nameLen = strlen(nameOfWave(nameWave))
	string pulseNum = nameOfWave(nameWave)[0,nameLen-6]
	
	//Start by creating output wave names
	string acetoneOutNameBase = "Acetone_" + pulseNum
	string ipaOutNameBase = "IPA_" + pulseNum
	string ipaAcetoneOutNameBase = "IPA_acetone_" + pulseNum
	
	//Make acetone fit param waves
	Make/N=5/D/O $(acetoneOutNameBase + "_base")
	Make/N=5/D/O $(acetoneOutNameBase + "_max")
	Make/N=5/D/O $(acetoneOutNameBase + "_x0")
	Make/N=5/D/O $(acetoneOutNameBase + "_rate")
	
	//Make ipa fit param waves
	Make/N=5/D/O $(ipaOutNameBase + "_base")
	Make/N=5/D/O $(ipaOutNameBase + "_max")
	Make/N=5/D/O $(ipaOutNameBase + "_x0")
	Make/N=5/D/O $(ipaOutNameBase + "_rate")
	
	//Make ipa/acetone fit param waves
	Make/N=5/D/O $(ipaAcetoneOutNameBase + "_base")
	Make/N=5/D/O $(ipaAcetoneOutNameBase + "_max")
	Make/N=5/D/O $(ipaAcetoneOutNameBase + "_x0")
	Make/N=5/D/O $(ipaAcetoneOutNameBase + "_rate")
	
	string chemicalNamesRegex = "Acetone.*;IPA_\d.*;IPA_Acetone.*"
	string rawChemNames = "Acetone;IPA;IPA_Acetone"
	string concentrations = "100nM;1uM;10uM;100uM;1mM"

	variable i
	variable j
	variable k
	
	
	//This is terrible but works 
	//Go through each fit name in the nameWave
	for (i = 0; i < numpnts(nameWave); i++)
		string currentFit = nameWave[i]
		
		//Iterate through all chemicals to check if == current fit name
		for (j = 0; j < itemsInList(chemicalNamesRegex); j++)
			string currentChemicalRegex = stringFromList(i, chemicalNamesRegex) 
			
			//find which conc the current fit name is 
			for (k = 0; k < itemsInList(concentrations); k++)
				//create the search string (ex: 100nM_Acetone.*)
				string currConcChem = stringFromList(k, concentrations) + "_" + stringFromList(j,chemicalNamesRegex)
			
				//current fit wave is a match
				if (grepString(currentFit, currConcChem))
					string baseWaveName = stringFromList(j, rawChemNames) + "_" + pulseNum + "_base"
					wave baseWave = $(baseWaveName) 
					baseWave[k] = resultWave[i][0] 
					
					wave maxWave = $(stringFromList(j, rawChemNames) + "_" + pulseNum + "_max")
					maxWave[k] = resultWave[i][1] 

					wave x0Wave = $(stringFromList(j, rawChemNames) + "_" + pulseNum + "_x0")
					x0Wave[k] = resultWave[i][2] 
					
					wave rateWave = $(stringFromList(j, rawChemNames) + "_" + pulseNum + "_rate")
					rateWave[k] = resultWave[i][3] 
					 
				endif 
				
			endfor
		endfor
	endfor	
	
End


//Create 3d plot for selected OGT responses

Function plotResponses3D([wavesToGraph])
	string wavesToGraph
	
	if (paramIsDefault(wavesToGraph))
		wavesToGraph = ""
		
		variable i = 0
		do
			string nextItem = GetBrowserSelection(i)
			if (strlen(nextItem) <= 0)
				break
			endif
			
			wavesToGraph = AddListItem(nextItem, wavesToGraph)
			i++
			
		while(1)
	endif
	
	//Make sure user selected waves in browser
	if (strlen(wavesToGraph) <= 0)
		DoAlert 0, "User Must select at least one wave from data browser"
		return 1
	endif
	
	NewGizmo


	for (i = 0; i < itemsInList(wavesToGraph); i++)
		wave currentWave = $stringFromList(i, wavesToGraph)
		
		
		string WaveName3d = nameOfWave(currentWave) + "_3dWave"

		//Check if 3d wave already exists
		if (!waveExists($WaveName3d))
			//Generate xaxis wave with same length as response
			variable lengthResponse = numpnts(currentWave)
			string xAxisName = "xAxis_" + num2str(lengthResponse)
			
			Make/N=(lengthResponse)/D/O $xAxisName
			wave xAxisWave = $xAxisName
			xAxisWave = x
			
			string zAxisName = "zAxis_" + num2str(i) + "_" + num2str(lengthResponse)
			Make/N=(lengthResponse)/D/O $zAxisName
			wave zAxisWave = $zAxisName
			zAxisWave = i
			
			concatenate/O {xAxisWave, currentWave, zAxisWave}, $WaveName3d
			
				
			
		endif
				AppendToGizmo path=$waveName3d
		variable pathNum = i
		string currentObject = "path" + num2str(i)
		ModifyGizmo setDisplayList=pathNum, object=$currentObject
		
			//Color path
		Variable pathR = 0
		Variable pathG = 0
		Variable pathB = 0
		Variable pathA = 1
	
		Variable currentNum = mod(pathNum,31)
	
		if(currentNum != 0)
			if(currentNum == 1)
				ModifyGizmo ModifyObject=$currentObject, objectType=path, property={pathColor, 0, 0, 1, 1}	
			endIf
			if(currentNum == 2)
				ModifyGizmo ModifyObject=$currentObject, objectType=path, property={pathColor, 0, 1, 0, 1}	
			endIf
			if(currentNum == 3)
				ModifyGizmo ModifyObject=$currentObject, objectType=path, property={pathColor, 1, 0, 0, 1}	
			endIf
		endif
		
	endfor
	
	//Add Axes
	ModifyGizmo stopUpdates
	AppendToGizmo Axes=BoxAxes,name=axes0
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 2,axisLabel,1}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 6,axisLabel,1}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 11,axisLabel,1}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 2,axisLabelText,"Test Number"}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 6,axisLabelText,"Voltage"}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 11,axisLabelText,"Point Number"}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={2,axisLabelCenter,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={6,axisLabelCenter,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={11,axisLabelCenter,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 2,axisLabelDistance,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 6,axisLabelDistance,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 11,axisLabelDistance,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 2,axisLabelScale,1}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 6,axisLabelScale,1}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 11,axisLabelScale,1}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 2,axisLabelRGBA,0.000000,0.000000,0.000000,1.000000}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 6,axisLabelRGBA,0.000000,0.000000,0.000000,1.000000}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 11,axisLabelRGBA,0.000000,0.000000,0.000000,1.000000}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 2,axisLabelTilt,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 6,axisLabelTilt,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 11,axisLabelTilt,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={2,axisLabelFont,"default"}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={6,axisLabelFont,"default"}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={11,axisLabelFont,"default"}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 2,axisLabelFlip,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 6,axisLabelFlip,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 11,axisLabelFlip,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 2,labelBillboarding,1}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 6,labelBillboarding,1}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 11,labelBillboarding,1}
	ModifyGizmo resumeUpdates
	ModifyGizmo setDisplayList=(pathNum + 1), object=axes0
	
	//add axis numbering
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 11,ticks,3}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ 6,ticks,3}
	
	
	//Add legend
	string annotationText = ""
	for (i = 0; i < itemsInList(wavesToGraph); i++)
		annotationText += num2str(i+1) + ": " + stringFromList(i, wavesToGraph) + "\n"
	endfor 
	
	//Remove last newline
	annotationText = annotationText[0, strlen(annotationText)-2]
	
	TextBox/C/N=text0/A=MT annotationText

	
End

//Create fit parameter graphs for the analytical samples
Function createConcGraph()
	string wavesToGraph = ""
		
	variable i = 0
	do
		string nextItem = GetBrowserSelection(i)
		if (strlen(nextItem) <= 0)
			break
		endif
		
		wavesToGraph = AddListItem(nextItem, wavesToGraph)
		i++
			
	while(1)
	
	
	//Make sure user selected waves in browser
	if (itemsInList(wavesToGraph) != 12)
		DoAlert 0, "User Must select 12 fit param waves (base, max, x0, and rate) all tests"
		return 1
	endif
	


	wave baseWave
	wave maxWave
	wave x0Wave
	wave rateWave
	
	
	Display/K=0 
	string baseMaxGraphName = WinName(0,1)
	Display/K=0
	string x0RateGraphName = WinName(0,1)
	
	//Find all 4 waves 
	for (i = 0; i < itemsInList(wavesToGraph); i++)
		string currentWaveName = stringFromList(i, wavesToGraph)
		
		if (strsearch(currentWaveName, "_base", 0) != -1)
			//Current wave is base
			wave baseWave = $currentWaveName
			AppendToGraph/W=$baseMaxGraphName baseWave
			continue
		endif 
		
		if (strsearch(currentWaveName, "_max", 0) != -1)
			//Current wave is max
			wave maxWave = $currentWaveName
			AppendToGraph/R/W=$baseMaxGraphName maxWave
			continue
		endif
		
		if (strsearch(currentWaveName, "_x0", 0) != -1)
			//Current wave is x0
			wave x0Wave = $currentWaveName
			AppendToGraph/W=$x0RateGraphName x0Wave
			continue
		endif
		
		if (strsearch(currentWaveName, "_rate", 0) != -1)
			//Current wave is rate
			wave rateWave = $currentWaveName
			AppendToGraph/R/W=$x0RateGraphName rateWave
			continue
		endif
		
	endfor
	

	//Make markers
	ModifyGraph/W=$x0RateGraphName mode=3
	ModifyGraph/W=$baseMaxGraphName mode=3
	setMarkersColorType(graphName=x0RateGraphName)
	setMarkersColorType(graphName=baseMaxGraphName)
	
	ModifyGraph/W=$baseMaxGraphName userticks(bottom)= {root:pos_wave, root:conc_wave}
	ModifyGraph/W=$x0RateGraphName userticks(bottom)= {root:pos_wave, root:conc_wave}
	
	SetAxis/W=$x0RateGraphName bottom *,6
	SetAxis/W=$baseMaxGraphName bottom *,6
	Legend/W=$x0RateGraphName/C/N=text0/A=MC
	Legend/W=$baseMaxGraphName/C/N=text0/A=MC
	
	ModifyGraph/W=$x0RateGraphName mirror(bottom)=1;DelayUpdate
	ModifyGraph/W=$baseMaxGraphName mirror(bottom)=1;DelayUpdate

	Label/W=$baseMaxGraphName left "Base";DelayUpdate
	Label/W=$baseMaxGraphName right "Max"
	Label/W=$baseMaxGraphName bottom "Concentration"

	Label/W=$x0RateGraphName left "x0";DelayUpdate
	Label/W=$x0RateGraphName right "Rate"
	Label/W=$x0RateGraphName bottom "Concentration"	
	
	string chemicalName
	if (strSearch(currentWaveName, "Acetone", 0) != -1 || strSearch(currentWaveName, "acetone", 0) != -1)
		chemicalName = "Acetone"
	endif

	if (strSearch(currentWaveName, "IPA", 0) != -1)
		chemicalName = "IPA"
	endif	
	
	if (strSearch(currentWaveName, "IPA_acetone", 0) != -1)
		chemicalName = "IPA/Acetone"
	endif
	
	
	string testNum
	if (strSearch(currentWaveName, "test1", 0) != -1)
		testNum = "Test 1"
	endif

	if (strSearch(currentWaveName, "test2", 0) != -1)
		testNum = "Test 2"
	endif	
	
	if (strSearch(currentWaveName, "test3", 0) != -1)
		testNum = "Test 3"
	endif
	
	if (strSearch(currentWaveName, "test4", 0) != -1)
		testNum = "Test 4"
	endif
	
	string baseTextBox = chemicalName + " " + testNum + "\n" + "All Pulses\nBase and Max"
	string x0TextBox = chemicalName + " " + testNum + "\n" + "All Pulses\nx0 and Rate"
	TextBox/W=$baseMaxGraphName/C/N=text1/A=MC baseTextbox
	TextBox/W=$x0RateGraphName/C/N=text1/A=MC x0TextBox
		
End

//This function is made to be called by createConcGraph() above
Function setMarkersColorType([graphName])
	string graphName
	
	if (paramIsDefault(graphName))
		graphName=WinName(0,1)
	endif
	
	if( strlen(graphName) == 0 )
    	DoAlert 0, "Expected graph"
    	return 1
    endif
    
    String traces= TraceNameList(graphName,";",1)


	
	
    variable i
    for (i = 0; i < itemsInList(traces); i++)
    	string currentTraceName = stringFromList(i, traces)
    	
		//Determine chemical type and change color/shape
		if (strsearch(currentTraceName, "IPA", 0) != -1)
		
			//set IPA to blue shades depending on pulse num
			if (strsearch(currentTraceName, "pulse1", 0) != -1)
				ModifyGraph/W=$graphName rgb($currentTraceName)=(0,0,65535)
			elseif (strsearch(currentTraceName, "pulse2", 0) != -1)
				ModifyGraph/W=$graphName rgb($currentTraceName)=(32768,32770,65535)
			elseif (strsearch(currentTraceName, "pulse3", 0) != -1)
				ModifyGraph/W=$graphName rgb($currentTraceName)=(49151,49152,65535)	
			endif
			
			
			if ((strsearch(currentTraceName, "base", 0) != -1) || (strsearch(currentTraceName, "x0", 0) != -1))
				//Open circle
				ModifyGraph/W=$graphName marker($currentTraceName)=8
			else
				//close circle
				ModifyGraph/W=$graphName marker($currentTraceName)=19
			endif
		endif
		
		if (strsearch(currentTraceName, "Acetone", 0) != -1 || strsearch(currentTraceName, "acetone", 0) != -1)
		
			//set Acetone to red shades
			if (strsearch(currentTraceName, "pulse1", 0) != -1)
				ModifyGraph/W=$graphName rgb($currentTraceName)=(65535,0,0)
			elseif (strsearch(currentTraceName, "pulse2", 0) != -1)
				ModifyGraph/W=$graphName rgb($currentTraceName)=(65535,32768,32768)
			elseif (strsearch(currentTraceName, "pulse3", 0) != -1)
				ModifyGraph/W=$graphName rgb($currentTraceName)=(65535,49151,49151)	
			endif			
			
			
			if ((strsearch(currentTraceName, "base", 0) != -1) || (strsearch(currentTraceName, "x0", 0) != -1))
				//Open square
				ModifyGraph/W=$graphName marker($currentTraceName)=5
			else
				//close square
				ModifyGraph/W=$graphName marker($currentTraceName)=16
			endif
		endif
		
		if (strsearch(currentTraceName, "IPA_acetone", 0) != -1)
			
			
			//set mixture to black
			if (strsearch(currentTraceName, "pulse1", 0) != -1)
				ModifyGraph/W=$graphName rgb($currentTraceName)=(0,0,0)
			elseif (strsearch(currentTraceName, "pulse2", 0) != -1)
				ModifyGraph/W=$graphName rgb($currentTraceName)=(17476,17476,17476)
			elseif (strsearch(currentTraceName, "pulse3", 0) != -1)
				ModifyGraph/W=$graphName rgb($currentTraceName)=(26214,26214,26214)	
			endif			
			
			if ((strsearch(currentTraceName, "base", 0) != -1) || (strsearch(currentTraceName, "x0", 0) != -1))
				//Open square
				ModifyGraph/W=$graphName marker($currentTraceName)=5
			else
				//close square
				ModifyGraph/W=$graphName marker($currentTraceName)=16
			endif
		endif
	endfor
End