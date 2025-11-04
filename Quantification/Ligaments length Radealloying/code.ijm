requires("1.42p");

var SAVE_IMG = false;
var CIRCLE_AREA = 1;
var AREA_ALL = 0;
var isKeepHole = false;
var isBottomToTop = false;
var LEVEL_NUM = 100;

windowname = "Count White Area in Range";

var LOWER=0;
var upper=0;
var hole_lower=0;
var HOLE_UPPER=0;
var SCALE_Pixle=1;//每1单位右几个pixel；

var COUNT_INDEX = 0;
var TOTAL_RATIO = 0;
var TOTAL_Area_pixel = 0;
var TOTAL_white_pixel = 0;


var MeanNorRatio = 0;
var StdDevNorRatio = 0;


var RC = 0;
title1 = "Summary Table";
title2 = "["+title1+"]";
f = title2;
	



//标定
function biaoding(w_id) { 
// function description
	//setBatchMode(true);
	
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel global");
	do {
	// Prompt user to select image boundaries
		setTool(4);//Straight line
		beep();
		waitForUser("Calibration", "Select scale line, then click OK.");

	} while(selectionType() == -1);
	
	//run("Threshold...");

	scale_p = getValue("Length");
	
	
	 Dialog.create("Set..");
	 
	 Dialog.addNumber("Known Distance:", 10);
  	 Dialog.addString("Unit of length:", "um");
  	 Dialog.addNumber("Distance in pixel:",scale_p);
  	 Dialog.addMessage("============");
  	 Dialog.addNumber("Normalized points:", 1000);

  	  Dialog.addCheckbox("Keep hole?", true);
  	  Dialog.addCheckbox("Bottom to top?", false);
  	  Dialog.addCheckbox("Keep mask?", false);
  	 Dialog.show();
 	scale_r = Dialog.getNumber();
 	
  	unit_str = Dialog.getString();
  	pixel_scale = Dialog.getNumber();
  	
  	SCALE_Pixle = scale_p/scale_r;//每单位几个pixel
  	LEVEL_NUM =  Dialog.getNumber();
  	
  	//print("SCALE_Pixle:",SCALE_Pixle);
  	isKeepHole = Dialog.getCheckbox();
  	isBottomToTop = Dialog.getCheckbox();
  	SAVE_IMG = Dialog.getCheckbox();
  	
  	if (scale_r==0) exit("ERROR: Set number of Scale Distance is 0 ,please run again");

  	cmd = "distance="+toString(scale_p)+" known="+toString(scale_r)+" pixel=1 unit="+unit_str+" global";
  	run("Set Scale...", cmd);

}



//获取竖直线上的每个比值
function GetTotalRatio(maskid,Min_gray, levelnum,dir, fname) { 
	setBatchMode(true);
	
	selectImage(maskid);
	getDimensions(imgwidth, imgheight, channels, slices, frames);
	
	run("Select All");
	roiManager("Add");
	roiManager("Select", 0);
	roiManager("Select", newArray(0,1));
	roiManager("AND");
	roiManager("Add");
	roiManager("Select", newArray(0,1));
	roiManager("Delete");
	
	
	if(isBottomToTop){
		run("Select None"); 
		run("Flip Vertically");//如果孔隙垂直方向由下往上，就水平翻转黑白图
		
		roiManager("Select", 0); //ROI 选区翻转
		run("Create Mask");
		tmp_id = getImageID();
		run("Flip Vertically");
		run("Create Selection");
		roiManager("Add");
		
		roiManager("Select", 0);
		roiManager("Delete");
		selectImage(tmp_id);
		close();
	
	}
	selectImage(maskid);
	roiManager("Select", 0);

	getSelectionBounds(x, y, width, height);
	
	min_right_width = minOf(imgwidth, width);
	x = abs(x);
	max_left_x = minOf(0,  x);
	
	//run("Create Mask");
	//rename("mask_all");
	
	list_ratio_porosity = newArray(min_right_width);
	list_col_nor_ratio_porosity = newArray(levelnum);
	list_col_nor_ratio_count = newArray(levelnum);
	
	roiManager("Select", 0);
	
	//run("Fit Rectangle");
	
	
	//print(x, y, width, height);
	y1 = y;
	y2 = y+height;
	
	right_x = max_left_x+min_right_width;

	for (x_i = max_left_x; x_i < right_x ; x_i++) {
		
		
		gray_value_count = 0;
		roiManager("Select", 0);
		ys = y1;
		ye = y2;
		for(y_fs = y1;y_fs <y2; y_fs++){
			
			if(selectionContains(x_i, y_fs)){
				ys = y_fs;
				break;
			}
		}
		for(y_fe = ys+1;y_fe <y2; y_fe++){
			
			if(!selectionContains(x_i, y_fe)){
				ye = y_fe;
				break;
			}
		}
		
		
		for(y_i = ys; y_i< y_fe+1; y_i++){
			value = getValue(x_i, y_i);
			if(value> Min_gray){
				gray_value_count++;
			}
		}
		
		row_ratio = gray_value_count/(ye-ys);
		
		list_ratio_porosity[x_i] = row_ratio;
		lenght_row = ye-ys;
		
		for (i = 0; i < levelnum+1; i++) {
			new_y = ys+lenght_row*i/levelnum;
			if(!selectionContains(x_i, new_y)) continue;
	
			nor_value = getValue(x_i, new_y);
			if(nor_value>Min_gray){
				
				list_col_nor_ratio_porosity[i] = list_col_nor_ratio_porosity[i]+1;
			}
			list_col_nor_ratio_count[i] = list_col_nor_ratio_count[i]+1;
		}
	}
	
	
	for (l = 0; l < levelnum; l++) {
		
		v = list_col_nor_ratio_porosity[l] / list_col_nor_ratio_count[l]*100; 
		if(isNaN(v)) v= 0;
		list_col_nor_ratio_porosity[l] = v;
	}
	
	setBatchMode(false);
	x_list = Array.getSequence(levelnum);
	Plot.create("Animated Plot", "level", "Radio with normalized depth %", x_list, list_col_nor_ratio_porosity);
    setJustification("center");
    Plot.update();
    
    selectImage("Animated Plot");
    
    sub_fname = File.getNameWithoutExtension(fname);
	tif_path =  dir +File.separator+sub_fname+"_RadioNomalizeDepth.tif";
	saveAs("Tiff", tif_path);
	
    Array.getStatistics(list_col_nor_ratio_porosity, min, max, mean, stdDev);
	MeanNorRatio = mean;
	StdDevNorRatio = stdDev;
	//Array.print(list_col_nor_ratio_porosity);
	//print(" min, max, mean, stdDev total_ratio", min, max, mean, stdDev, TOTAL_RATIO);
}

function getRC(maskid, dir, fname){
	
	selectImage(maskid);
	run("Set Measurements...", "area perimeter shape feret's area_fraction redirect=None decimal=3");
	//run("Analyze Particles...", "size=10-Infinity pixel display clear add");
	run("Analyze Particles...", "size=10-Infinity pixel display");
	
	selectWindow("Results");
	nline = getValue("results.count");
	
	code = "D1divD2= Feret/MinFeret; DC = sqrt(MinFeret*Feret);";
	Table.applyMacro(code);


	Table.renameColumn('Feret', "d1");
	Table.renameColumn('MinFeret', "d2");
	
	Table.deleteColumn("%Area");
	Table.deleteColumn("FeretX");
	Table.deleteColumn("FeretY");
	Table.deleteColumn("FeretAngle");
	Table.deleteColumn("AR");
	Table.deleteColumn("Round");
	Table.deleteColumn("Solidity");
	updateResults();
	
	dc_array = Table.getColumn("DC");
	Array.getStatistics(dc_array, dcmin, dcmax, dcmean, dcstdDev);

	RC = dcmean/2;
	//print("RC=",RC);
	sub_fname = File.getNameWithoutExtension(fname);
	csv_path =  dir +File.separator+sub_fname+"_MeasureResults.csv";
	selectWindow("Results");
	saveAs("Text",csv_path );
}


//设置外轮廓选框
function setOutlineSelecte(savedir, fname){
	
	do {
	// Prompt user to select image boundaries
		setTool(2);//polygon 
		beep();
		waitForUser("Outline", "Select Outline ROI, then click OK.");
	} while(selectionType() == -1);
	roiManager("Add");
	selectImage("HoleMaskImg");
	roiManager("Select", 0);
	setForegroundColor(255, 255, 255);
	setBackgroundColor(0, 0, 0);
	run("Clear Outside");
	
	per_area = getValue("%Area");
	TOTAL_RATIO = per_area;
	roiManager("Select", 0);
	
	getRawStatistics(count);
	
	TOTAL_Area_pixel = count;
	TOTAL_white_pixel = count*per_area/100;

	
	roi_path =  dir +File.separator+fname+".roi";
	roiManager("Save", roi_path);
	run("Select None");
}

function removeNosie(maskid) { 
	// function description
	setBatchMode(true);
	selectImage(maskid);
	run("Despeckle");
	run("Options...", "iterations=1 count=1 black do=Close");
	
	run("Analyze Particles...", "size=0-20 pixel clear add");
	setForegroundColor(0, 0, 0);
	setBackgroundColor(255, 255, 255);
	roiManager("Fill");
	roiManager("Deselect");
	
	run("Set Measurements...", "area perimeter shape feret's area_fraction limit redirect=None decimal=3");
	//setAutoThreshold("Default dark");
	setThreshold(0, 10);
	//run("Threshold...");
	roiManager("Deselect");
	run("Analyze Particles...", "size=0-20 pixel clear add");
	setForegroundColor(255, 255, 255);
	setBackgroundColor(0, 0, 0);
	roiManager("Fill");
	resetThreshold();
	roiManager("reset");
	setBatchMode(false);
}



macro "title1" {
	fname = getInfo("image.filename");
	dir = getInfo("image.directory");
	
	wid = getImageID();
	biaoding(wid);//标定
	
	img_type_bit = bitDepth();
	setOption("BlackBackground", true);
	
	roiManager("reset");
	run("Remove Overlay");
	
	
	run("Threshold...");
	setThreshold(100, 255, "raw");
	waitForUser("SetInitThroldNum", "set min Threshold for white point, then click OK.");
	getThreshold(LOWER, upper);
	run("Create Selection");
	Roi.setName("white-roi");
	roiManager("add");
	run("Select None");
	
	
	if(isKeepHole){
		resetThreshold();
		run("Threshold...");
		setThreshold(0, 100, "raw");
		waitForUser("SetInitHoleThresholdNum", "set max Threshold for black porosity, then click OK.");
		getThreshold(hole_lower, HOLE_UPPER);
		
		run("Select None");
		run("Create Selection");
		run("Create Mask");
		run("Despeckle");
		run("Options...", "iterations=1 count=1 black do=Open");
		rename("HoleMaskImg");
		run("Create Selection");
		Roi.setName("hole-roi");
		roiManager("add");
		
		setForegroundColor(255, 255, 255);
		setBackgroundColor(0, 0, 0);
		roiManager("select", 0);
		roiManager("Fill");
		roiManager("Deselect");
	}
	else{
		roiManager("select", 0);
		run("Create Mask");
		run("Despeckle");
		run("Options...", "iterations=1 count=1 black do=Open");
		rename("HoleMaskImg");
	}
	
	maskid = getImageID();
	removeNosie(maskid);

	selectImage(wid);
	resetThreshold();
	run("Select None");

	setOutlineSelecte(dir,fname);
	
	
	GetTotalRatio(maskid,1, LEVEL_NUM, dir, fname);
	getRC(maskid,dir,fname);
	
	
	if (!isOpen(title1)){ //close(title1);
	//run("New... ", "name="+title2+" type=Table");
		run("Table...", "name="+title2+" width=600 height=400");
		print(f,"\\Headings:fname\t"+"Total White Area(pixel)\t"+"Total ROI Area(pixel)\t"+"Total Ratio%"+"\t"+"Mean of NorRatio%"+"\t"+ "Stddev of NorRatio%" +"\t"+"RC(um)");
	}
	
	
	print(f, fname+ "\t"+TOTAL_white_pixel+"\t"+TOTAL_Area_pixel+ "\t" + TOTAL_RATIO+"\t" +MeanNorRatio+"\t"+StdDevNorRatio+"\t"+RC);

	sub_fname = File.getNameWithoutExtension(fname);
	csv_path =  dir +File.separator+sub_fname+"_summary.csv";

	selectWindow("Summary Table");
	saveAs("Text",csv_path );

	if(SAVE_IMG )
	{	
		selectImage(maskid);
		if(isBottomToTop){
			run("Select None"); 
			run("Flip Vertically");//如果孔隙垂直方向由下往上，就水平翻转黑白图
		}
		s_name = dir +File.separator+sub_fname+"_mask.png";
		saveAs("PNG", s_name);
	}
	
}