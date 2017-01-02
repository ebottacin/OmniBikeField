using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as System;
using Toybox.Math as Math;
using Toybox.Lang as Lang;


class OmniBikeFieldApp extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }

    //! Return the initial view of your application here
    function getInitialView() {
        return [ new OmniBikeFieldView() ];
    }

}
 
class OmniBikeFieldView extends Ui.DataField {
    
    hidden const CENTER = Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER;
    hidden const HEADER_FONT = Gfx.FONT_XTINY;
    hidden const VALUE_FONT = Gfx.FONT_NUMBER_MEDIUM;
    hidden const VALUE_FONT_SM = Gfx.FONT_NUMBER_MILD;
    hidden const VAM_THRESHOLD =100;
    hidden const VAM_THRESHOLD_CLIMB =400;
    hidden const ALT_THRESHOLD = 200;
    
    hidden var mSingleField;
    hidden var mBgColor;
    hidden var mFgColor;
    
    hidden var mGpsSignal;
    //hidden var mIsDistanceUnitsMetric;
    //hidden var mIsSpeedUnitsMetric;
    hidden var mIs24Hour;
    
    hidden var mElapsedTime;
    hidden var mHr;
    hidden var mDst;
    hidden var mCad;
    hidden var mVel;    
    hidden var mCal;
    
    hidden var mVamSlopeCalculator;
    

    function initialize() {
        DataField.initialize();
        mVamSlopeCalculator = new VamSlopeCalculator();
       
        mSingleField=false;
        mGpsSignal =0;
        
        //mIsDistanceUnitsMetric = System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
        //mIsSpeedUnitsMetric = System.getDeviceSettings().paceUnits == System.UNIT_METRIC;
        mIs24Hour = System.getDeviceSettings().is24Hour;
        
        //System.println("init complete");
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        
		//System.println("onLayout - width: " +  width + ", height: " + height);
		 
        if (height != 148 || width != 205 ) {
            dc.drawText(width/2 - 15,height/2,Gfx.FONT_SYSTEM_TINY,"use 1 field layout",Gfx.TEXT_JUSTIFY_CENTER);
            mSingleField = false;

        // Use the generic, centered layout
        } else {
          setBgColor();
          //setLayout(dc);
          mSingleField=true;
        }

        return true;
    }

    // The given info object contains all the current workout
    // information. Calculate a value and save it locally in this method.
    function compute(info) {
        if(mSingleField){
           mVamSlopeCalculator.compute(info.altitude,info.currentLocation);
           mElapsedTime = info.elapsedTime != null ? info.elapsedTime / 1000 : 0 ;
           //mElapsedTime = 3599+3600;
           mHr = info.currentHeartRate != null ? info.currentHeartRate : 0 ;
           mDst = info.elapsedDistance != null ? info.elapsedDistance : 0;
           //mDst = 199999.0;
           mCad = info.currentCadence != null ? info.currentCadence : 0;
           mVel = info.currentSpeed != null ? info.currentSpeed : 0;
           mCal = info.calories != null ? info.calories : 0;
        }
        
        mGpsSignal = info.currentLocationAccuracy;
    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc) {
        
		if (mSingleField) {
			drawLayout(dc);     
		}
		//View.onUpdate(dc);
        
    }
    
    function drawLayout(dc) {
	    dc.setColor(Gfx.COLOR_TRANSPARENT, mBgColor);
        dc.clear();
        
        drawGps(dc,mGpsSignal);
        drawBattery(dc);
        drawTOD(dc);
        drawSlope(dc,mVamSlopeCalculator.getSlope());
		drawGrid(dc);
		drawFields(dc);
    }
    
    function setBgColor() {
        mBgColor = getBackgroundColor();
        if (mBgColor == Gfx.COLOR_BLACK) {
        	mFgColor = Gfx.COLOR_WHITE;
        } else if (mBgColor == Gfx.COLOR_WHITE) {
        	mFgColor = Gfx.COLOR_BLACK;
        } else {
        	mFgColor = Gfx.COLOR_RED;
        }
    }
    
    function drawGrid(dc) {
        dc.setColor(Gfx.COLOR_LT_GRAY,Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
		dc.drawLine(0, 22, dc.getWidth(), 22);
		dc.drawLine(73, 22, 73, 80);
		dc.drawLine(63, 89, 63, dc.getHeight());
		dc.drawLine(131, 22, 131, 80);
		dc.drawLine(141, 89, 141, dc.getHeight());
		dc.drawLine(0, 80, dc.getWidth(), 80);
		dc.drawLine(0, 89, dc.getWidth(), 89);
		
		dc.setColor(Gfx.COLOR_DK_GRAY,Gfx.COLOR_TRANSPARENT);
		
		dc.drawText(32, 30, HEADER_FONT, "TIME", CENTER);
        dc.drawText(101, 30, HEADER_FONT, "HR", CENTER);
        dc.drawText(168, 30, HEADER_FONT, "DST", CENTER);
        
        dc.drawText(34, 97, HEADER_FONT, "CAD", CENTER);
        var header;
        
        if (mVamSlopeCalculator.getVam()>VAM_THRESHOLD_CLIMB) {
        	header = "VAM/vel";
        } else if (mVamSlopeCalculator.getVam()>VAM_THRESHOLD_CLIMB) {
        	header = "VEL/vam";
        } else {
        	header = "VEL";
        }
        dc.drawText(101, 97, HEADER_FONT, header, CENTER);
        
        if (mVamSlopeCalculator.getAltitude()>ALT_THRESHOLD) {
        	header = "ALT/cal";
        } else {
        	header = "CAL";
        }
        dc.drawText(168, 97, HEADER_FONT, header, CENTER);
        
        dc.setPenWidth(1);    
    }
    
    function drawFields(dc) {
        dc.setColor(mFgColor,Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
		var formattedValue;
		
		//elapsed
		if ((mElapsedTime/3600)>0) {
			dc.drawText(2, 36, Gfx.FONT_XTINY, (mElapsedTime / 3600).format("%.1d"), CENTER);
			formattedValue = Lang.format("$1$:$2$", [ ((mElapsedTime % 3600) / 60), (mElapsedTime % 60).format("%.2d")]);
		} else {
			formattedValue = Lang.format("$1$:$2$", [ (mElapsedTime / 60), (mElapsedTime % 60).format("%.2d")]);
		}
		dc.drawText(35, 60, VALUE_FONT, formattedValue, CENTER);
		
		//hr
        dc.drawText(101, 60, VALUE_FONT, mHr, CENTER);
        
        //dst
        dc.drawText(168, 60, VALUE_FONT, calculateDistance(), CENTER);
        
        //Cadence
        dc.drawText(29, 125, VALUE_FONT, mCad, CENTER);
        
        //Vel-Vam
		if (mVamSlopeCalculator.getVam()>VAM_THRESHOLD_CLIMB) {
			//Vel-Vam
			dc.drawText(108, 118, VALUE_FONT_SM, mVamSlopeCalculator.getVam().format("%d"), Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
			dc.drawText(108, 136, Gfx.FONT_XTINY, calculateSpeed(), Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
		} else if (mVamSlopeCalculator.getVam()>VAM_THRESHOLD) {
			//Vel-Vam
			dc.drawText(108, 118, VALUE_FONT_SM, calculateSpeed(), Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
			dc.drawText(106, 136, Gfx.FONT_XTINY,  mVamSlopeCalculator.getVam().format("%d"), Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
		} else {
			//Vel
			dc.drawText(101, 125, VALUE_FONT, calculateSpeed(), CENTER);
		} 
		
		if (mVamSlopeCalculator.getAltitude()>ALT_THRESHOLD) {
			//Alt-Cal
	        dc.drawText(180, 118, VALUE_FONT_SM, mVamSlopeCalculator.getAltitude().format("%d"), Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
	        dc.drawText(180, 136, Gfx.FONT_XTINY, mCal, Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
		} else {
			//Cal
	        dc.drawText(168, 125, VALUE_FONT, mCal, CENTER);	
		}
        dc.setPenWidth(1);    
    }
    
     function calculateDistance() {
        if (mDst != null &&  mDst> 0) {
            //var distanceInUnit = info.elapsedDistance / (isDistanceUnitsMetric ? 1000 : 1610);
            var distanceInUnit = mDst / 1000;
            var distanceHigh = distanceInUnit >= 100.0;
            var distanceFullString = distanceInUnit.toString();
            var commaPos = distanceFullString.find(".");
            var floatNumber = 3;
            if (distanceHigh) {
            	floatNumber = 2;
            }
            return distanceFullString.substring(0, commaPos + floatNumber);
        } else {
        	return "---";
        }
    }
    
    function calculateSpeed() {
	    if (mVel !=null && mVel>0) {
	    	return (mVel*3.6).format("%.02f");
	    } else {
	    	return "---";
	    }
    }
    
    function drawTOD(dc) {
     	var clockTime = System.getClockTime();
        var time, ampm, timeX;
        var x= dc.getWidth()/2;
        
        if (mIs24Hour) {
            time = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%.2d")]);
            ampm = "";
            timeX = x;
        } else {
            time = Lang.format("$1$:$2$", [calculateAmPmHour(clockTime.hour), clockTime.min.format("%.2d")]);
            ampm = (clockTime.hour < 12) ? "am" : "pm";
            timeX = x;
        }
        dc.setColor(mFgColor,Gfx.COLOR_TRANSPARENT);
        dc.drawText(timeX, 10, Gfx.FONT_XTINY, time, CENTER);
        dc.drawText(timeX + 28, 10, Gfx.FONT_XTINY, ampm, CENTER);
    }
    
    function calculateAmPmHour(hour) {
        if (hour == 0) {
            return 12;
        } else if (hour > 12) {
            return hour - 12;
        }
        return hour;
    }
    
    
    
    function drawSlope(dc,slope) {
       	var xStart = 0;
       	var yStart = 80;
		var w=9;
		var h=6;   
		    
    	for (var i = 0; i < 23; i++) {
            var fillColor;
            if (i < 5) {
            	fillColor = Gfx.COLOR_GREEN;
            } else if ( i>=5 and i<10) {
            	fillColor = Gfx.COLOR_DK_GREEN;
            } else if ( i>=10 and i<15) {
            	fillColor = Gfx.COLOR_ORANGE;
            } else if ( i>=15 and i<20) {
            	fillColor = Gfx.COLOR_RED;
            } else {
            	fillColor = Gfx.COLOR_DK_RED;
            }
            
            dc.setColor(mFgColor,Gfx.COLOR_TRANSPARENT);
            if (i==5 || i == 10 || i == 15 || i ==20 || i ==25) {
            	dc.drawLine(xStart + 1 + i*w, yStart+5,xStart + 1 + i*w,yStart+9);
            } else {
            	dc.drawLine(xStart + 1 + i*w, yStart+7,xStart + 1 + i*w,yStart+9);
            }
            
            if (slope != null && i < slope) {
            	dc.setColor(fillColor,Gfx.COLOR_TRANSPARENT);
            	dc.fillRectangle(xStart + 3 + i*w, yStart + 2, 6, h);
            }    
        }
    }
    
    
    function drawGps(dc,gpsSignal) {
       // gps
        if (gpsSignal == null || gpsSignal < 2) {
            drawGpsSign(dc, 180, 0, Gfx.COLOR_LT_GRAY, Gfx.COLOR_LT_GRAY, Gfx.COLOR_LT_GRAY);
        } else if (gpsSignal == 2) {
            drawGpsSign(dc, 180, 0, Gfx.COLOR_DK_GREEN, Gfx.COLOR_LT_GRAY, Gfx.COLOR_LT_GRAY);
        } else if (gpsSignal == 3) {
            drawGpsSign(dc, 180, 0, Gfx.COLOR_DK_GREEN, Gfx.COLOR_DK_GREEN, Gfx.COLOR_LT_GRAY);
        } else {
            drawGpsSign(dc, 180, 0, Gfx.COLOR_DK_GREEN, Gfx.COLOR_DK_GREEN, Gfx.COLOR_DK_GREEN);
        }
    }


    function drawGpsSign(dc, xStart, yStart, color1, color2, color3) {
        dc.setColor(mFgColor,Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart - 1, yStart + 11, 8, 10);
        dc.setColor(color1, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(xStart, yStart + 12, 6, 8);

        dc.setColor(mFgColor,Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart + 6, yStart + 7, 8, 14);
        dc.setColor(color2, mBgColor);
        dc.fillRectangle(xStart + 7, yStart + 8, 6, 12);

        dc.setColor(mFgColor, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart + 13, yStart + 3, 8, 18);
        dc.setColor(color3, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(xStart + 14, yStart + 4, 6, 16);
    }
    
    
    function drawBattery(dc) {
        var yStart = 3;
        var xStart = 1;
       
        var batLevel = System.getSystemStats().battery;
        var barColor;
       	if (batLevel>=10) {
       		barColor = Gfx.COLOR_DK_GREEN;
       	} else {
       		barColor = Gfx.COLOR_DK_RED;
       	}

        dc.setColor(mFgColor,Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart, yStart, 29, 18);
        dc.drawRectangle(xStart + 1, yStart + 1, 27, 16);
        dc.fillRectangle(xStart + 29, yStart + 4, 2, 9);
        dc.setColor(barColor, Gfx.COLOR_TRANSPARENT);
        if (batLevel<10) {
        	dc.drawText(xStart+13, yStart + 1, Gfx.FONT_XTINY, batLevel.format("%1d"), Gfx.TEXT_JUSTIFY_CENTER);
        }
        for (var i = 0; i < (24 * System.getSystemStats().battery / 100); i = i + 3) {
            dc.fillRectangle(xStart + 3 + i, yStart + 3, 2, 12);    
        }
    }

}

class VamSlopeCalculator {

    hidden const BUFFER_SIZE=5;
    hidden const QUEUE_SIZE=5;
    hidden const R = 6372800; // metres
    
    hidden var mVamSamples;
    hidden var mSlopeSamples;
  
    hidden var mLocationBuffer;
    hidden var mAltitudeBuffer;
    hidden var mTick;
    
    hidden var mVamSpeed;
    hidden var mSlope;
    hidden var mAltitude;
  
    
    //! Set the label of the data field here.
    function initialize() {
       
        mVamSamples= new DataQueue(QUEUE_SIZE);
        mSlopeSamples = new DataQueue(QUEUE_SIZE);
        
  		mLocationBuffer = new DataBuffer(BUFFER_SIZE,"location");
  		mAltitudeBuffer = new DataBuffer(BUFFER_SIZE,"altitude");
  		mTick = 0;
  		mVamSpeed = 0;
  		mSlope = 0;
  		mAltitude = 0;
  		//System.println("VamSlope init complete");
    }

    //! The given info object contains all the current workout
    //! information. Calculate a value and return it in this method.
    function compute(altitude,location) {
    	
    	//System.println("tick:"+ mTick);
        if (location == null) {
        	if (mTick>0) {
        		mTick=0;
        		mAltitudeBuffer.reset();
        		mLocationBuffer.reset();
        		mSlopeSamples.reset();
        		mVamSpeed.reset();
        	}
        	return;
        }
        if (mTick>=(BUFFER_SIZE-1)) {
	        var prevAltitude = mAltitudeBuffer.pop();
	        mAltitudeBuffer.push(altitude);
	        
	        var prevDegrees = mLocationBuffer.pop();
	        var curDegrees = location.toDegrees();
	        mLocationBuffer.push(curDegrees);
	        
	        
	        
	        var dist = distance(prevDegrees[0].toDouble(),prevDegrees[1].toDouble(),curDegrees[0].toDouble(),curDegrees[1].toDouble());
	        
	        
	        if (dist != 0.0) {
		        if (prevAltitude != null && altitude != null) {
		        	var dAltitude = altitude - prevAltitude;
		        	//System.println("dist:" + dist + ", dAltitude: " + dAltitude);
		        	if ( dAltitude !=0) {
		        		var slope = Math.asin(dAltitude/dist)*100;
		        		var vam= (dAltitude*3600)/(BUFFER_SIZE-1);
		        		mSlopeSamples.add(slope);
		        		mVamSamples.add(vam);
		        		mVamSpeed = mVamSamples.getAverage();
		        		mSlope = mSlopeSamples.getAverage();
		        		mAltitude = mAltitudeBuffer.getAverage();
		        		//System.println("vam: " + mVamSpeed + ", slope: " + mSlope);
		        	}	
		        } 
		    }
	    } else {
	    	mTick++;
	    	mLocationBuffer.push(location.toDegrees());
	    	mAltitudeBuffer.push(altitude);
        }
        // See Activity.Info in the documentation for available information.
		//System.println("altitude: " + altitude + ", speed: " + speed + ", distance: " + dist);
    }
    
    function getVam() {
    	return mVamSpeed;
    }
    
    function getSlope() {
    	return mSlope;
    }
    
    function getAltitude() {
    	return mAltitude;
    }
 
 //Haversine Formula
  function distance(latitude1,longitude1,latitude2,longitude2) {
      //System.println("(lat1,lon1) , (lat2,lon2) = (" + latitude1 + "," + longitude1 + ") , (" + latitude2 +"," + longitude2 + ")");
	  //http://www.movable-type.co.uk/scripts/latlong.html

	  var dLat = deg2rad(latitude2-latitude1);
	  var dLon = deg2rad(longitude2-longitude1);
	  var lat1 = deg2rad(latitude1);
	  var lat2 = deg2rad(latitude2);
	  
	  var a = Math.pow(Math.sin(dLat / 2),2) + Math.pow(Math.sin(dLon / 2),2) * Math.cos(lat1) * Math.cos(lat2);
	  var c = 2 * Math.asin(Math.sqrt(a));
	  
	  return R * c;
	}
	
	
	function deg2rad(deg) {
	  return (deg * Math.PI / 180);
	}
	
}


//! A circular queue implementation.
//! @author Konrad Paumann
class DataQueue {

    //! the data array.
    hidden var data;
    hidden var maxSize = 0;
    hidden var pos = 0;
    hidden var numValidSamples;

    //! precondition: size has to be >= 2
    function initialize(arraySize) {
        data = new[arraySize];
        maxSize = arraySize;
        numValidSamples=0;
    }
    
    //! Add an element to the queue.
    function add(element) {
        data[pos] = element;
        pos = (pos + 1) % maxSize;
        if (numValidSamples<maxSize) {
        	numValidSamples++;
        }
    }
    
    //! Reset the queue to its initial state.
    function reset() {
        for (var i = 0; i < data.size(); i++) {
            data[i] = null;
        }
        pos = 0;
        numValidSamples=0;
    }
    
    function getAverage() {
    	var avg=0;
    	if (numValidSamples>0) {
	    	for (var i=0; i<numValidSamples;i++) {
	    		avg+=data[i];		
	    	}
	    	avg= avg /numValidSamples;
    	}
    	return avg;
    }
     
}

class DataBuffer {

    //! the data array.
    hidden var data;
    hidden var type;
    hidden var maxSize;
    hidden var startPos;
    hidden var endPos;

    //! precondition: size has to be >= 2
    function initialize(bufferSize,des) {
        data = new[bufferSize];
        type = des;
        maxSize = bufferSize;
        startPos = 0;
        endPos = 0;
    }
    
   
    function push(element) {
    	//System.println("push  (endPos: " + endPos + ",startPos:" + startPos + ") for element " + element); 
        data[endPos] = element;
        endPos = (endPos + 1) % maxSize;
        //System.println("buffer : " + toString());
        
    }
    
    
    function pop() { 
    	//System.println("pop (endPos: " + endPos + ",startPos:" + startPos + ")");
        var element=null;
        element = data[startPos];
        startPos = (startPos + 1) % maxSize;
        //System.println("buffer : " + toString());
        return element;
    }
    
    /*
     function push(element) { 
        if ((endPos>startPos && ((endPos + 1) % maxSize)==startPos) || (endPos<startPos && endPos+1==startPos)) {
        	System.println("buffer overflow");
        } else {
        	//System.println("push at endPos: " + endPos + " for element " + element);
        	data[endPos] = element;
        	endPos = (endPos + 1) % maxSize;
        	//System.println("buffer : " + toString());
        }
    }
    
    
    function pop() { 
        var element=null;
        if (endPos==startPos) {
        	System.println("buffer overflow");
        } else {
        	//System.println("pop at startPos: " + startPos);
        	element = data[startPos];
        	startPos = (startPos + 1) % maxSize;
        	//System.println("buffer : " + toString());
        }
        return element;
    }
    */
    function getBufferSize() {
    	if (endPos<startPos) {
    		return (endPos+maxSize)-startPos;
    	} else {
    		return endPos-startPos;
    	}
    }
    
    function isFull() {
    	if (getBufferSize()==maxSize-1) {
    		return true;
    	} else {
    		return false;
    	}
    }
    
     function getAverage() {
    	var avg=0;
    	var numValidSamples=0;
    	//System.println("average on buffer : " + toString());
    	if (startPos!=endPos) {
	    	if (startPos<endPos) {
		    	for (var i=startPos; i<=endPos;i++) {
		    		avg+=data[i];
		    		numValidSamples++;		
		    	}
		    } else {
		    	for (var i=startPos; i<=endPos+maxSize;i++) {
		    		avg+=data[i % maxSize];
		    		numValidSamples++;		
		    	}
		    }
	    	avg= avg /numValidSamples;
    	}
    	//System.println("buffer average : " + avg);
    	return avg;
    }
    
   
    //! Reset the queue to its initial state.
    function reset() {
        for (var i = 0; i < data.size(); i++) {
            data[i] = null;
        }
        startPos = 0;
        endPos = 0;
    }
   
   /*
    function toString() {
    	var ret = "";
    	for (var i=0; i<maxSize;i++) {
    		if (i!= 0) {
    			ret += ",";
    		}
    		ret+=data[i];		
    	}
    
    	return "[type=" + type + "][startPos=" + startPos + "][endPos=" + endPos + "][" + ret + "]";
    }
   */
}
