#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

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


// Load all csvs in the specificed directory path
// creates 3 waves from the collected OGT data (time, ogt response, and the light pulse waveform)
// Returns list of generated response waves on success, -1 or error
Function/S loadFilesFromDir(userPath)
	String userPath
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
		wave w = $baseWname + "_time"
		
		//If wave does not exist create it
		if (!waveexists(w))
			//Load csv data as 3 waves (time, measured response, and pulse
			LoadWave/J/D/A/P=loadPath/K=0 stringfromlist(i, filelist)
			
			//rename waves 
			String timeWave = baseWname + "_time"
			rename wave0 $timeWave
			String responseWave = baseWname + "_response"
			rename wave1  $responseWave
			String pulseWave = baseWname + "_pulse"
			rename wave2 $pulseWave
			
			//Add wavename to responseList
			responseList = responseList + responseWave + ";"
			
			//Print name of loaded file
			print "Loaded " + fname
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
Function convolveAirAndSampleDir([userPath, displayFlag])
	String userPath
	variable displayFlag
	
	String responseList
	String graphName
	
	if (ParamIsDefault(userPath))
		getfilefolderInfo/D
		responseList = loadFilesFromDir(S_path)
	else
		 responseList = loadFilesFromDir(userPath)
	endif
	
	
	//Find the initial air response file
	String airResponse
	variable i = 0
	do
		String currentResponse = stringfromList(i, responseList)
		//Check if filename contains air and initial, when found remove from list
		if (GrepString(currentResponse, "air") && GrepString(currentResponse, "initial"))
			airResponse = currentResponse
			//responseList = removeFromList(airResponse, responseList)
			break
		endif
		i += 1
	while(i < itemsinList(responseList))	
	
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
	
	for (i = 0; i < itemsInList(responseList); i++)
		String currentWave = stringfromList(i, responseList)
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
	endfor
	
	if (displayFlag == 1)
		quickColorSpectrum(graphName)
		Legend/C/N=text0/W=$graphName
	endif
	
End