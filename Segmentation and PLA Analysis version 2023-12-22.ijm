// Jan Wisniewski, EIB/NCI/NIH, Bethesda, MD

print("PLA Analysis\nJan Wisniewski, Experimental Immunology Branch\nNational Cancer Institute, NIH, Bethesda, Maryland");
print("version 2023-12-22");
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
print("");
print("run: ", month+1, "/", dayOfMonth, "/", year, "   at ", hour, ":", minute);
print("");

showMessage("* Activate Bio-Formats(Windowless) import option\n     prior to runing this Macro for the first time\n \n* Images for analysis need to be in a separate folder,\n     without any other files of subfolders inside.\n \n* Store results in a different folder");

//  specify folders
res=getDirectory("Choose/create Results Folder");
myDir1 = res+"TEMP_1"+File.separator;
File.makeDirectory(myDir1);
myDir2 = res+"TEMP_2"+File.separator;
File.makeDirectory(myDir2);
myDir3 = res+"TEMP_3"+File.separator;
File.makeDirectory(myDir3);
myDir4 = res+"TEMP_4"+File.separator;
File.makeDirectory(myDir4);
input=getDirectory("Select Source Folder");
NAMES=getFileList(input); 

lei=endsWith(NAMES[0], ".lif");
if(lei==1) {// convert Leica images to tif
setBatchMode(true);
myDir5 = res + "Tiffs" + File.separator;
File.makeDirectory(myDir5);

dwn=getDirectory("downloads");
dest=dwn+"X.lif";			

for (k = 0; k < NAMES.length; k++) {showProgress(k/NAMES.length);
File.copy(input + NAMES[k], dwn + "X.lif");
run("Bio-Formats", "open=[dest] autoscale color_mode=Default open_all_series rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");

lclst=getList("image.titles");
for (u = 0; u < lclst.length; u++) {selectWindow(lclst[u]);
			saveAs("Tif", myDir5 + NAMES[k]+"_"+u+1); 
			close();		} 		}			
setBatchMode(false);
input=myDir5;
NAMES=getFileList(input); 		}

run("Brightness/Contrast...");
run("Colors...", "foreground=white background=black selection=yellow");

//set measured parameters
run("Set Measurements...", "area mean min bounding integrated median display redirect=None decimal=2");

//create custom table
title1 = "Analysis Table"; 
title2 = "["+title1+"]"; 
f=title2; 
run("New... ", "name="+title2+" type=Table"); 
print(f,"\\Headings:Image\tTarget_ID\tPosition\t \tNuclear_Area(um2)\tCytosol_Area(um2)\tSpot_Detection_Threshold\tNuclear_Spots\tCytosol_Spots\tNuclear_Spots/um2\tCytosol_Spots/um2\tNuclear/Cytosol_Density_Ratio"); 

//channel setup
open(input+NAMES[0]);
ttl=File.nameWithoutExtension;
getDimensions(width, height, channels, slices, frames);
ns=channels;
rename("x");
run("Split Channels");
run("Tile");

for (i = 0; i < ns; i++) {selectWindow("C"+i+1+"-x");
run("Enhance Contrast", "saturated=0.35");	}

Dialog.create("Channel selection");
items=newArray("C1-x", "C2-x", "C3-x", "C4-x");
itemz=newArray("Grays", "Blue", "Cyan", "Green", "Yellow" ,"Red", "Magenta");
Dialog.addRadioButtonGroup("Select Channel to create Nucleus Mask:", items, 1, 3, "C4-x");
Dialog.addString("Name the mask:", "nuclei");
Dialog.addChoice("Display as:", itemz, "Cyan");
Dialog.addNumber("Set minimum size of nucleus (um2)", 15);
Dialog.addNumber("Set maximum size (um2):", 80);
Dialog.addMessage("     *     *     *     *     *     *     *     *     *     *");
Dialog.addRadioButtonGroup("Select Channel to create Cell Mask:", items, 1, 3, "C2-x");
Dialog.addString("Name the mask:", "cells");
Dialog.addChoice("Display as:", itemz, "Green");
Dialog.addMessage("     *     *     *     *     *     *     *     *     *     *");
Dialog.addRadioButtonGroup("Select Channel to measure:", items, 1, 3, "C1-x");
Dialog.addString("Name the measured structure:", "PLA");
Dialog.addChoice("Display as:", itemz, "Red");
Dialog.show();

MCh=Dialog.getRadioButton();
MNm=Dialog.getString();
MCo=Dialog.getChoice();
smll=Dialog.getNumber();
lrg=Dialog.getNumber();
CCh=Dialog.getRadioButton();
CNm=Dialog.getString();
CCo=Dialog.getChoice();
PCh=Dialog.getRadioButton();
PNm=Dialog.getString();
PCo=Dialog.getChoice();

print("setup image:", ttl);
print(MNm, MCh, MCo);
print("valid nucleus size range:", smll, "-", lrg, "um2");
print(CNm, CCh,CCo);
print(PNm, PCh, PCo);
run("Cascade");

//thresholds for nuclei detection
selectWindow(MCh);
run(MCo);
run("Duplicate...", "title=nuclei");

run("Median...", "radius=2");
setAutoThreshold("Default dark");
run("Threshold...");
setThreshold(0, 65535);
waitForUser("Adjust threshold to select nuclei.\nClick on the uppermost bar to rise minimum a few steps.");
getThreshold(lower, upper);
thrlow=lower;
thrup=upper;
run("Convert to Mask");
	run("Grays");
	run("Options...", "iterations=8 count=3 pad do=Open");
	run("Invert");
	run("Fill Holes");
	close("Threshold");
	run("Invert");
	run("Minimum...", "radius=2");
	setTool("freehand");
setOption("BlackBackground", true);
print("Nucleus segmentation thresholds:", thrlow, "-", thrup);
nprom=100;
print("nuclei detection limit (prominence):", nprom);
close("nuclei");

//threshold for cell detection
selectWindow(CCh);
run(CCo);
run("Duplicate...", "title=cells");
run("Maximum...", "radius=2");
setAutoThreshold("Default dark");
run("Threshold...");
setThreshold(0, 65535);
waitForUser("Adjust threshold to detect cells - be generous with cell size.\nClick on the uppermost bar to rise minimum one or two steps.");
getThreshold(lower, upper);
clow=lower;
cup=upper;
run("Convert to Mask");
	run("Grays");
	run("Options...", "iterations=8 count=3 pad do=Open");
	run("Invert");
	run("Fill Holes");
	close("Threshold");
	run("Invert");
	run("Minimum...", "radius=2");
print("Cell segmentation thresholds:", clow, "-", cup);
close("cells");

//threshold for dots
selectWindow(PCh);
run(PCo);
run("Duplicate...", "title=bck");
run("Gaussian Blur...", "sigma=5");
imageCalculator("Subtract create", PCh,"bck");
rename("spots");
run("Enhance Contrast", "saturated=0.35");
run("Median...", "radius=2");

run("Point Tool...", "type=Dot color=Yellow size=Small label counter=0");
waitForUser("Activate Preview in the next Dialog Window and adjust Prominence until points select correctly!\n \nEnter that value in the next Dialog box.");
run("Find Maxima...", "prominence=100 strict exclude output=[Point Selection]");
run("Select None");
run("Find Maxima...");
Dialog.create("Spot detection threshold");
Dialog.addNumber("Enter Prominence value from the previous step:", 50);
Dialog.show();
prom=Dialog.getNumber();
print("spot detection limit (prominence):", prom);
close("spots");
close("bck");

for (i = 0; i < ns; i++) {close("C"+i+1+"-x");	}

//proces images
for (i=0; i<NAMES.length; i++) {h=i+1;
	showProgress(h/(NAMES.length+1));	
setBatchMode(true); 
open(input+NAMES[i]);
ttx=File.nameWithoutExtension;

selectWindow("Analysis Table");
wait(500);
print(f, ttx);

if(i==0) {getPixelSize(unit, pixelWidth, pixelHeight);
pxum2=1/(pixelWidth*pixelHeight);
print("pixel size=",pixelWidth, "x", pixelHeight, unit, "   ", pxum2, "pixels/um2");

getDimensions(width, height, channels, slices, frames);
wdt=width;
hgt=height;
nc=channels;	}

rename("x");
run("Split Channels");
selectWindow(MCh);
	run(MCo);
	run("Enhance Contrast", "saturated=0.35");
	run("Duplicate...", " ");
	rename(MNm);
	run("Duplicate...", " ");
	rename(MNm+"_copy");
selectWindow(CCh);
	run(CCo);
	run("Enhance Contrast", "saturated=0.35");
	run("Duplicate...", " ");
	rename(CNm);
	run("Duplicate...", " ");
	rename(CNm+"_copy");
selectWindow(PCh);
	run(PCo);
	run("Enhance Contrast", "saturated=0.35");
	run("Duplicate...", " ");
	rename(PNm);
	run("Duplicate...", " ");
	rename(PNm+"_copy");
for (j = 0; j < nc; j++) {close("C"+j+1+"-x");	}

run("Cascade");
selectWindow(MNm);
run("Median...", "radius=2");
run("Threshold...");
setAutoThreshold("Default dark");
setThreshold(thrlow, thrup);
run("Convert to Mask");
	run("Grays");
	run("Options...", "iterations=8 count=3 pad do=Open");
	run("Invert");
	run("Fill Holes");
	close("Threshold");
	run("Invert");
	run("Minimum...", "radius=2");
setOption("BlackBackground", true);
rename("nucl");
run("Duplicate...", "title=vor");
run("Voronoi");
run("Multiply...", "value=255");
run("Invert");
run("Divide...", "value=255");
run("Enhance Contrast", "saturated=0.35");

selectWindow("nucl");
run("Point Tool...", "type=Dot color=Red size=[Extra Large] label counter=0");
run("Find Maxima...", "prominence=nprom strict exclude output=List");
			selectWindow("Results");
			rs=Table.size(); 
			if(rs>0) {rs=Table.size();Table.sort("X"); //
					Table.rename("X_Y_list");

selectWindow(PNm);
run("Duplicate...", "title=bck");
run("Gaussian Blur...", "sigma=5");
imageCalculator("Subtract create", PNm,"bck");
rename("spots");
run("Enhance Contrast", "saturated=0.35");
run("Median...", "radius=2");
run("Point Tool...", "type=Dot color=Yellow size=Small label counter=0");
run("Find Maxima...", "prominence=prom strict exclude output=[Single Points]");
run("Grays");
rename("points");
close("bck"); 

//cells
selectWindow(CNm);
run("Maximum...", "radius=2");
run("Threshold...");
setAutoThreshold("Default dark");
setThreshold(clow, cup);
run("Convert to Mask");
	run("Grays");
	run("Options...", "iterations=8 count=3 pad do=Open");
	run("Invert");
	run("Fill Holes");
	close("Threshold");
	run("Invert");
	imageCalculator("Add create", CNm, "nucl");
	rename("slct");
	run("Minimum...", "radius=2");
//close("cells");
imageCalculator("Subtract create", "slct","nucl");
imageCalculator("Multiply create", "Result of slct","vor");
rename("band");
imageCalculator("Multiply create", "vor", "slct");
rename("vorcells");
close("slct");
close("Result of slct");
close("vor");

run("Images to Stack", "name=Stack title=[] use");
run("Reverse");
run("Enhance Contrast", "saturated=0.35");

for (q = 0; q < rs; q++) {selectWindow("X_Y_list");
			xxt=Table.get("X", q);
			yyt=Table.get("Y", q);
			selectWindow("Stack");
			roiManager("Show All with labels");
			run("Select None");
			run("Duplicate...", "title=s duplicate");
		aa="x="+xxt;
		bb="y="+yyt;
		m=aa+" "+bb;
			doWand(xxt, yyt);
			run("Clear Outside", "stack");
				roiManager("Add");
				run("Select None");

selectWindow("s");
	run("Duplicate...", "title=temp_stack duplicate");
selectWindow("s");
roiManager("Show None");
run("Restore Selection");
run("Crop");
run("Select None");
run("Stack to Images");

selectWindow("nucl");
run("Divide...", "value=255");
setMinAndMax(0, 1);
run("Measure");
nar=getResult("RawIntDen");
narum=nar/pxum2;
selectWindow("nucl");
run("Multiply...", "value=255");

run("Images to Stack", "name=s title=[] use");
if(narum<smll) {close("s");
			close("temp_stack");	}
else {if(narum>lrg) {close("s");
			close("temp_stack");	}
	else {selectWindow("temp_stack");
	run("Stack to Images");
	selectWindow("nucl");
	run("Convert to Mask");
	run("Grays");
	saveAs("Tif", myDir2+"nucleus_"+q+1);
	selectWindow(CNm);
	run("Convert to Mask");
	run("Grays");
	saveAs("Tif", myDir3+"cell_"+q+1);
	run("Images to Stack", "name=temp_stack title=[] use");
	close("temp_stack");

selectWindow("s");
run("Stack to Images");

selectWindow(CNm);
run("Divide...", "value=255");
setMinAndMax(0, 1);
run("Measure");
vorarp=getResult("RawIntDen");
cellarp=vorarp-nar;
cellum=cellarp/pxum2;

selectWindow("nucl");
run("Divide...", "value=255");

selectWindow("points");
imageCalculator("Multiply create", "nucl","points");
rename("a");
run("Find Maxima...", "prominence=10 strict exclude output=Count");
nucnbr=getResult("Count");


selectWindow(CNm);
imageCalculator("Multiply create", CNm,"points");
rename("d");
run("Find Maxima...", "prominence=10 strict exclude output=Count");
vornbr=getResult("Count");
cellnbr=vornbr-nucnbr;
imageCalculator("Subtract create", "d","a");
rename("b");
run("8-bit");
run("Multiply...", "value=255");
run("Maximum...", "radius=1");
run("Gaussian Blur...", "sigma=1");
run("Enhance Contrast", "saturated=0.35");
close("Results");
close("points");
close("band");
close("d");

selectWindow("a");
run("8-bit");
run("Maximum...", "radius=1");
run("Gaussian Blur...", "sigma=1");
run("Enhance Contrast", "saturated=0.35");

selectWindow("vorcells");
run("8-bit");
run("Invert");
run("Outline");
run("Invert");

selectWindow("nucl");
run("Multiply...", "value=255");
run("8-bit");
run("Invert");
run("Outline");
run("Invert");

selectWindow(MNm+"_copy");
run("Enhance Contrast", "saturated=0.35");
run("8-bit");
run("Cyan");
rename("w");
run("Merge Channels...", "c4=nucl c5=w create keep");
run("RGB Color");
rename("nsel");
getDimensions(width, height, channels, slices, frames);
fr_WW=width+20;
fr_HH=height+20;
run("Canvas Size...", "width=fr_WW height=fr_HH position=Center");
close("Composite");

selectWindow(CNm+"_copy");
run("Enhance Contrast", "saturated=0.35");
run("8-bit");
run(CCo);
rename("v");
run("Merge Channels...", "c2=v c4=vorcells create keep");
run("RGB Color");
rename("csel");
run("Canvas Size...", "width=fr_WW height=fr_HH position=Center");
close("Composite");

selectWindow(PNm+"_copy");
run("Enhance Contrast", "saturated=0.35");
run("8-bit");
run(PCo);
rename("u");
run("Merge Channels...", "c1=u c4=nucl create keep");
run("RGB Color");
rename("psel");
run("Canvas Size...", "width=fr_WW height=fr_HH position=Center");
close("Composite");

close(PNm);
close(CNm);
close("spots");
close("u");
close("v");
close("w");

run("Merge Channels...", "c1=a c2=vorcells c5=nucl c6=b create ignore");
run("RGB Color");
run("Canvas Size...", "width=fr_WW height=fr_HH position=Center");

close("Composite");

run("Images to Stack", "name=comp title=[] use");
run("Make Montage...", "columns=2 rows=2 scale=1");
saveAs("Tif", myDir1+"cell_"+q+1);
close();
close("comp");
nucden=nucnbr/narum;
cellden=cellnbr/cellum;
rtio=nucden/cellden;

selectWindow("Analysis Table");
wait(500);
print(f," "+"\t"+q+1+"\t"+m+"\t"+" "+"\t"+narum+"\t"+cellum+"\t"+prom+"\t"+nucnbr+"\t"+cellnbr+"\t"+nucden+"\t"+cellden+"\t"+rtio);	}	}	}

roiManager("Save", myDir4 + "RoiSet.zip");
close("ROI Manager");

lst1=getFileList(myDir1);
for (k = 0; k < lst1.length; k++) {open(myDir1+lst1[k]);	}
if(lst1.length>1) {run("Images to Stack", "method=[Copy (center)] name=TEMP_1 title=[] use");

tmp=lst1.length/5;
rws=Math.ceil(tmp);
run("Make Montage...", "columns=5 rows=rws scale=1 border=5 label");	}
saveAs("Tif", res+ttx+"_select");
close();
close("TEMP_1");


lst2=getFileList(myDir2);
open(myDir2);
if(lst2.length>1) {run("Z Project...", "projection=[Max Intensity]");		}
rename("NUCS");
close("TEMP_2");
run("Convert to Mask");
run("Outline");
run("Cyan");

lst3=getFileList(myDir3);
open(myDir3);
if(lst3.length>1) {run("Z Project...", "projection=[Max Intensity]");		}
rename("CLLS");
close("TEMP_3");
run("Convert to Mask");
run("Outline");
run("Yellow");

selectWindow("Stack");
run("Select None");
run("Stack to Images");

close(CNm);
close(PNm+"_copy");
close("nucl");
close("band");
close("vorcells");
close("spots");

selectWindow(MNm+"_copy");
resetMinAndMax();
run("Enhance Contrast", "saturated=0.35");
run("8-bit");
run(MCo);
rename("nuclei");
run("RGB Color");
saveAs("Tif", myDir4 + "nuclei");
close();
	
selectWindow(CNm+"_copy");
resetMinAndMax();
run("Enhance Contrast", "saturated=0.35");
run("8-bit");
run(CCo);
rename("cells");
run("RGB Color");
saveAs("Tif", myDir4 + "cells");
close();

selectWindow(PNm);
resetMinAndMax();
run("Enhance Contrast", "saturated=0.35");
run("8-bit");
run(PCo);
rename("PLA");
run("RGB Color");
saveAs("Tif", myDir4 + "PLA");
close();

selectWindow("points");
run("Multiply...", "value=257");
run("Gaussian Blur...", "sigma=1");
run("Enhance Contrast", "saturated=0.35");
run("8-bit");
run(PCo);

run("Merge Channels...", "c1=points c5=NUCS c7=CLLS");
saveAs("Tif", myDir4 + "merged");
close();
setBatchMode(false);
wait(1000);

open(myDir4 + "merged.tif");
open(myDir4 + "PLA.tif");
rename("PLA");
open(myDir4 + "nuclei.tif");
rename("nuclei");
open(myDir4 + "cells.tif");
rename("cells");
open(myDir4 + "RoiSet.zip");
selectWindow("merged.tif");
roiManager("Show All with Labels");
run("Flatten");
rename(ttx+"_selected");
close("merged");

run("Images to Stack", "name=Stack title=[] use");
run("Reverse");
run("Set Scale...", "distance=1 known=pixelWidth unit=um");
run("Make Montage...", "columns=2 rows=2 scale=1 border=4 font=25 label");
run("Scale Bar...", "width=10 height=2 font=15 color=White background=None location=[Lower Right]");
saveAs("Tif", res+ttx);
close();
close("Stack");
close("ROI Manager");
close("X_Y_list");

for (p = 0; p < lst1.length; p++) 
ok=File.delete(myDir1+lst1[p]);
lst2=getFileList(myDir2);
for (p = 0; p < lst2.length; p++) 
ok=File.delete(myDir2+lst2[p]);
lst3=getFileList(myDir3);
for (p = 0; p < lst3.length; p++) 
ok=File.delete(myDir3+lst3[p]);
lst4=getFileList(myDir4);
for (p = 0; p < lst4.length; p++) 
ok=File.delete(myDir4+lst4[p]);			}	
else {nim=nImages;
for (c = 0; c < nim; c++) {close();		}
print(f," "+"\t"+"no detections");		}	
close("Results");		close("Results");}

ok = File.delete(myDir1);
ok = File.delete(myDir2);
ok = File.delete(myDir3);
ok = File.delete(myDir4);

selectWindow("Analysis Table");
saveAs("Text", res+"Analysis_Results.csv");
close("Analysis Table");
selectWindow("Log");
saveAs("Text", res+"Log");
close("Log");
exit("RUN COMPLETED!");

