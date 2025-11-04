requires("1.42p");

var SAVE_IMG = false;
var CIRCLE_AREA = 1;
var AREA_ALL = 0;
var isKeepHole = false;

var ROI_W = 0;
var ROI_H = 0;

windowname = "Count White Area in Range";
var Threshold_step = 5;

var LOWER=0;
var upper=0;
var hole_lower=0;
var HOLE_UPPER=0;
var SCALE_Pixle=1;//每1单位右几个pixel；

var COUNT_INDEX = 0;

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
	
	
	 Dialog.create("设置标尺");
	 
	 Dialog.addNumber("实际长度:", 10);
  	 Dialog.addString("单位:", "um");
  	 Dialog.addNumber("选中直线(pixel):",scale_p);
  	 //Dialog.addMessage("选中面积(pixel):"+toString(CIRCLE_AREA));
  	 
  	 Dialog.addNumber("ROI宽(实际尺寸):", 10);
  	 Dialog.addNumber("ROI高(实际尺寸):", 10);
  	 Dialog.addNumber("Threshold步长:", 5);
  	 
  	  Dialog.addCheckbox("保存测量图", false);
  	  Dialog.addCheckbox("保留孔洞", false);
  	 Dialog.show();
 	scale_r = Dialog.getNumber();
 	
  	unit_str = Dialog.getString();
  	pixel_scale = Dialog.getNumber();
  	ROI_W = Dialog.getNumber();
  	ROI_H = Dialog.getNumber();
  	Threshold_step = Dialog.getNumber();
  	SAVE_IMG = Dialog.getCheckbox();
  	SCALE_Pixle = scale_p/scale_r;//每单位几个pixel
  
  	//print("SCALE_Pixle:",SCALE_Pixle);
  	isKeepHole = Dialog.getCheckbox();
  	
  	
  	if (scale_r==0) exit("标定数值为 0 错误 ，请重新运行");

  	cmd = "distance="+toString(scale_p)+" known="+toString(scale_r)+" pixel=1 unit="+unit_str+" global";
  	run("Set Scale...", cmd);

}

//打印数据到窗口
function ShowDataToTable(sub_fname, array_frac,array_len,index) { 

	s = " ";
	//len = lengthOf(array_frac);
	
	for (i = 0; i < array_len-1; i++) {
		s = s+toString(array_frac[i]/index) + "\t";
	}
	s = s+toString(array_frac[array_len-1]/index);
	
	print(f, sub_fname  + "\t" + s);
}


//取不同阈值，并判断孔洞是否需要增加
function setDiffThreshold(Rect_area_num, Hole_area_num, index, sum_array_frac) { 
	
	run("Set Measurements...", "area area_fraction limit redirect=None decimal=3");

	array_frac = newArray(COUNT_INDEX);
	
	roi_n = roiManager('count');
	roiManager("select", roi_n-1);
	count= 0;
	for (i = 0; i < COUNT_INDEX+1; i++) {
		resetThreshold();
		th_value = LOWER+i*Threshold_step;	
		if(th_value>255)break;
		setThreshold(th_value, 255, "raw");
		cur_total_area = getValue("Area limit");
		  frac_area = 100.0*(cur_total_area+Hole_area_num)/Rect_area_num; 
		  array_frac[i] = frac_area;
		  sum_array_frac[i] = sum_array_frac[i]+frac_area;
		  count+=1;
		  //print("Area: ",cur_total_area,Hole_area_num,Rect_area_num, th_value);
	}

	ShowDataToTable(index, array_frac, count, 1);
	
}

//设置选框
function DrawSelecteRect(sid, thr_num_count) { 
	selectImage(wid);
	
	sum_array_frac = newArray(thr_num_count+1);
	shift=1;
	ctrl=2; 
	rightButton=4;
	alt=8;
	leftButton=16;
	insideROI = 32; // requires 1.42i or later
	index = 0;


	flag = getBoolean("生成ROI:右击鼠标,自动创建ROI，点击OK，进入修改状态");
	if(!flag) return;
	
	do {
		X=0;
		Y=0;
		W = SCALE_Pixle*ROI_W;
		H = SCALE_Pixle*ROI_H;
		 if (getVersion>="1.37r")
		    setOption("DisablePopupMenu", true);
		    
		
		do { 
			// Prompt user to select region of interest (default to polygon selection tool)
		
		      x2=-1; y2=-1; z2=-1; flags2=-1;
		      logOpened = false;
		    
		         
		      while (true) {
		          getCursorLoc(x, y, z, flags);
		          if (x!=x2 || y!=y2 || z!=z2 || flags!=flags2) {
		              if (flags&rightButton!=0){//点击鼠标右键
		              	//s = s + "<right>";
		              	
		              	X=x;
						Y=y;
		              	break;
		              }
		              
		              startTime = getTime();
		          }
		          x2=x; y2=y; z2=z; flags2=flags;
		          wait(10);
		      }
		      
		      makeRectangle(X-W/2, Y-H/2, W, H);
			  //print("ROI:",X-W/2, Y-H/2, W, H);
			
		} while(selectionType() == -1); 
		setOption("DisablePopupMenu", false);
		waitForUser("移动ROI","按住鼠标左键拖动，需要修改ROI位置,完成点击OK");
		
		// Overlay label for selected ROI
		Rect_area_num = getValue("Area");
		roiManager("add");
		roi_n = roiManager('count');

		//run("Add Selection...");
		//run("Labels...", "color=white font=10 show use bold");
		setBatchMode(true);
		Hole_area_num = 0;
		if(isKeepHole){
  			//selectWindow("HoleMaskImg");
  			//run("Create Selection");
			roiManager("Select", newArray(0,roi_n-1));
			roiManager("AND");
			Hole_area_num = getValue("Area");
			roiManager("Add");

			selectImage(sid);
			roiManager("Select", roi_n);
			Roi.setFillColor("#4dff0000");
			run("Add Selection...");
			roiManager("Delete");
  		}
		
		
		
		//waitForUser("kk");
		index +=1;
		setDiffThreshold(Rect_area_num, Hole_area_num, index, sum_array_frac);

		setBatchMode(false);
		// Ask user whether to repeat density measurements
		repeat = getBoolean("Would you like to calculate the proportion of another region?\n 请在需要位置右击鼠标");
	} while(repeat);
	
	array_len = lengthOf(sum_array_frac);
	ShowDataToTable("Mean", sum_array_frac,array_len,index);
	resetThreshold();

}


macro "title1" {
	fname = getInfo("image.filename");
	dir = getInfo("image.directory");
	
	wid = getImageID();
	biaoding(wid);//标定
	
	img_type_bit = bitDepth();
	if(img_type_bit !=8) run("8-bit");

	
	roiManager("reset");
	run("Remove Overlay");
	
	
	run("Threshold...");
	setThreshold(100, 255, "raw");
	waitForUser("SetInitThroldNum", "set min Threshold for 白点, then click OK.");
	getThreshold(LOWER, upper);
	
	if(isKeepHole){
		resetThreshold();
		run("Threshold...");
		setThreshold(0, 100, "raw");
		waitForUser("SetInitHoleThresholdNum", "set max Threshold for 黑孔, then click OK.");
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
	}
	
	selectImage(wid);
	resetThreshold();
	run("Select None");
	
	start = LOWER;
	COUNT_INDEX = floor((256-LOWER)/Threshold_step); 
	mod =  (256-LOWER)%Threshold_step;
	if(mod!=0) COUNT_INDEX = COUNT_INDEX+1;
	
	t = " ";
	for (i = 0; i < COUNT_INDEX; i++) {
		th_value = start+i*Threshold_step;
		t = t+toString(th_value) + "\t";
	}
	
	if (isOpen(title1))close(title1);
	//run("New... ", "name="+title2+" type=Table");
	run("Table...", "name="+title2+" width=600 height=400");
	print(f,"\\Headings:index\t"+t);
	
	
	DrawSelecteRect(wid, COUNT_INDEX);
	
	
	sub_fname = File.getNameWithoutExtension(fname);
	csv_path =  dir +File.separator+sub_fname+"_MeasureResults.csv";
	
	selectWindow("Summary Table");
	saveAs("Text",csv_path );
	
	if(SAVE_IMG )
	{
		
		if(isKeepHole)
		{
			roiManager("select", 0);
			roiManager("delete");
		}
			
		setOption("Show All", true);
		roiManager("show all with labels");
		run("Flatten");
		s_name = dir +File.separator+sub_fname+"_roi.png";
		saveAs("PNG", s_name);
	}
	
}