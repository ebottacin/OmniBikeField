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
   
	hidden var VAM_THRESHOLD =100;
    hidden var VAM_THRESHOLD_CLIMB =400;
    hidden var ALT_THRESHOLD = 200;
    
     //Drivetrain Loss (%)
    hidden var LOSS_DT = 3;    
    //Frontal Area (m^3)
    hidden var F_A = 0.509;
    //Drag Coefficent
    hidden var C_D = 0.63;
    //Rolling Resistance Coefficent
    hidden var C_RR = 0.005;
    //Air density (kg/m^3)
    hidden var RHO = 1.226;
    //Gravity Acceleration
    hidden var G = 9.8067;
    
    hidden var uHrZones = [ 93, 111, 130, 148, 167, 185 ];
    
    hidden var mSingleField;
    hidden var mBgColor;
    hidden var mFgColor;
    
    hidden var mGpsSignal;
    //hidden var mIsDistanceUnitsMetric;
    //hidden var mIsSpeedUnitsMetric;
    //hidden var mIs24Hour;
    
    hidden var mElapsedTime;
    hidden var mHr;
    hidden var mDst;
    hidden var mCad;
    hidden var mVel;    
    hidden var mPwr;
    
    hidden var mBikeW=8;
    hidden var mUserW=80;
    
    hidden var mVamSlopeCalculator;
    

    function initialize() {
        DataField.initialize();
        mVamSlopeCalculator = new VamSlopeCalculator();
        mSingleField=false;
        mGpsSignal =0;
       
        /*
        var app = Application.getApp();
 		
 		mBikeW = app.getProperty("pBikeWeight");
 		
 		VAM_THRESHOLD = app.getProperty("pVAMThreshold");
 		VAM_THRESHOLD_CLIMB = app.getProperty("pVAMThresholdClimb");
 		ALT_THRESHOLD = app.getProperty("pAltitudeThreshold");
 		LOSS_DT = app.getProperty("pDTLoss");
 		F_A = app.getProperty("pFrontalArea");
 		C_D = app.getProperty("pDragCoefficent");
 		C_RR = app.getProperty("pRollingRestanceCoefficent");
 		RHO = app.getProperty("pAirDensity");
 		G = app.getProperty("pGravityAcceleration");
        */
        
        //mIsDistanceUnitsMetric = System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
        //mIsSpeedUnitsMetric = System.getDeviceSettings().paceUnits == System.UNIT_METRIC;
        //mIs24Hour = System.getDeviceSettings().is24Hour;
        
        var mProfile = UserProfile.getProfile();
        if (mProfile != null) {
	 		uHrZones = UserProfile.getHeartRateZones(UserProfile.getCurrentSport());
	 		mUserW = mProfile.weight != null ? mProfile.weight/1000: 80; 
	 	}
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
           	mElapsedTime = info.timerTime != null ? info.timerTime / 1000 : 0 ;
           	//mElapsedTime = 3599+3600;
           	mHr = info.currentHeartRate != null ? info.currentHeartRate : 0 ;
           	mDst = info.elapsedDistance != null ? info.elapsedDistance : 0;
           	//mDst = 199999.0;
           	mCad = info.currentCadence != null ? info.currentCadence : 0;
           	mVel = info.currentSpeed != null ? info.currentSpeed : 0;
           	if (info has :currentPower) {
           		mPwr = info.currentPower;
           	} else if (mVel>0) {
           		mPwr = calculatePwr(mVamSlopeCalculator.getSlope(),mVel);
   			} else {
   				mPwr = 0;
   			}
   			mGpsSignal = info.currentLocationAccuracy;
        }
    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc) {
		if (mSingleField) {
			drawLayout(dc);     
		}
    }
    
    function drawLayout(dc) {
	    setBgColor();
	    
	    dc.setColor(Gfx.COLOR_TRANSPARENT, mBgColor);
        dc.clear();
        
        drawGps(dc,mGpsSignal);
        drawBattery(dc);
        drawTOD(dc);
        //drawSlope(dc,mVamSlopeCalculator.getSlope());
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
		
		 //! HR zone
    	var color = Graphics.COLOR_LT_GRAY; //! No zone default light grey
    	if (mHr != 0) {
			if (uHrZones != null) {
				if (mHr >= uHrZones[4]) {
					color = Graphics.COLOR_RED;		//! Maximum (Z5)
				} else if (mHr >= uHrZones[3]) {
					color = Graphics.COLOR_ORANGE;	//! Threshold (Z4)
				} else if (mHr >= uHrZones[2]) {
					color = Graphics.COLOR_GREEN;		//! Aerobic (Z3)
				} else if (mHr >= uHrZones[1]) {
					color = Graphics.COLOR_BLUE;		//! Easy (Z2)
				} //! Else Warm-up (Z1) and no zone both inherit default light grey here
			}
    	}
		dc.setColor(color, Gfx.COLOR_TRANSPARENT);
		dc.fillRectangle(74, 23, 58, 16);
        dc.setColor(mFgColor,Gfx.COLOR_TRANSPARENT);				
        dc.drawText(101, 30, HEADER_FONT, "HR", CENTER);
        
        dc.setColor(Gfx.COLOR_DK_GRAY,Gfx.COLOR_TRANSPARENT);
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
        	header = "PWR/alt";
        } else {
        	header = "PWR";
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
		
        dc.drawText(101, 60, VALUE_FONT, (mHr==0 ? "--" :mHr), CENTER);
        
        //dst
        dc.drawText(168, 60, VALUE_FONT, calculateDistance(), CENTER);
        
        //Cadence
        dc.drawText(29, 125, VALUE_FONT, (mCad>0 ? mCad : "---"), CENTER);
        
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
	        dc.drawText(180, 118, VALUE_FONT_SM,  mPwr.format("%d"), Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
	        dc.drawText(180, 136, Gfx.FONT_XTINY, mVamSlopeCalculator.getAltitude().format("%d"), Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
		} else {
			//pwr
	        dc.drawText(168, 125, VALUE_FONT, (mPwr>0 ? mPwr.format("%d") : "---"), CENTER);	
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
    
   
    
    //https://www.gribble.org/cycling/power_v_speed.html
    function calculatePwr(slope,vel) {
        if (vel==0 || slope == null) {
        	return 0;
        }
    	var dtLoss = Math.pow(1-(LOSS_DT/100),-1);
    	var fGravity = G* (mBikeW + mUserW) * Math.sin(Math.atan(slope/100));
    	var fRolling = G * (mBikeW + mUserW) * Math.cos(Math.atan(slope/100))*C_RR;
    	var fDrag = 0.5 * C_D * F_A * RHO * vel * vel;
    	
    	var pwr =dtLoss*(fGravity+fRolling+fDrag)*vel;
    	
    	return pwr>0 ? pwr : 0;
    }
    
    function drawTOD(dc) {
     	var clockTime = System.getClockTime();
        var time, ampm;
        var x= dc.getWidth()/2;
        time = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%.2d")]);
        dc.setColor(mFgColor,Gfx.COLOR_TRANSPARENT);
        dc.drawText(x, 10, Gfx.FONT_XTINY, time, CENTER);
    }
    
    /*
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
    */
    
    function drawGps(dc,gpsSignal) {
    	var color;
    	if (gpsSignal == null || gpsSignal < 2) {
            color = Gfx.COLOR_RED;
        } else if (gpsSignal == 2) {
            color = Gfx.COLOR_ORANGE;
        } else if (gpsSignal == 3) {
            color = Gfx.COLOR_DK_GREEN;
        } else {
            color = Gfx.COLOR_GREEN;
        }
        dc.setColor(color,Gfx.COLOR_TRANSPARENT);
        dc.drawText(190, 10, Gfx.FONT_SYSTEM_XTINY, "GPS", CENTER);
    }
    
    function drawBattery(dc) {
        var batLevel = System.getSystemStats().battery;
        var barColor;
       	if (batLevel>=10) {
       		barColor = mFgColor;
       	} else {
       		barColor = Gfx.COLOR_DK_RED;
       	}
		dc.setColor(barColor,Gfx.COLOR_TRANSPARENT);
        dc.drawText(3, 2, Gfx.FONT_XTINY, "Bat: "+batLevel.format("%1d") +"%", Gfx.TEXT_JUSTIFY_LEFT);
    }
} // end View

class VamSlopeCalculator {

    hidden const BUFFER_SIZE=5;
    hidden const QUEUE_SIZE=5;
    hidden const R = 6372800; // metres
    
    hidden var mSamples;
    hidden var mBuffer;
    hidden var mTick;
    
    hidden var mVamSpeed;
    hidden var mSlope;
    hidden var mAltitude;
  
    
    //! Set the label of the data field here.
    function initialize() {
       
        //mVamSamples= new DataBuffer(QUEUE_SIZE,"vam");
        //mSlopeSamples = new DataBuffer(QUEUE_SIZE,"slope");
        mSamples = new DataBuffer(QUEUE_SIZE);
        
        mBuffer = new DataBuffer(BUFFER_SIZE);
  		//mLocationBuffer = new DataBuffer(BUFFER_SIZE,"location");
  		//mAltitudeBuffer = new DataBuffer(BUFFER_SIZE,"altitude");
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
        		mSamples.reset();
        		mBuffer.reset();
        	}
        	return;
        }
        if (mTick>=(BUFFER_SIZE-1)) {
	        var prevBufElement = mBuffer.pop();
	        var prevAltitude = prevBufElement[0];
	        var prevDegrees = prevBufElement[1];
	       	var curDegrees = location.toDegrees(); 
	       	
	        mBuffer.push([altitude,location.toDegrees()]);
	         
	        var dist = distance(prevDegrees[0].toDouble(),prevDegrees[1].toDouble(),curDegrees[0].toDouble(),curDegrees[1].toDouble());
	         
	        if (dist != 0.0) {
		        if (prevAltitude != null && altitude != null) {
		        	var dAltitude = altitude - prevAltitude;
		        	//System.println("dist:" + dist + ", dAltitude: " + dAltitude);
		        	if ( dAltitude !=0) {
		        		var slope = Math.asin(dAltitude/dist)*100;
		        		var vam= (dAltitude*3600)/(BUFFER_SIZE-1);
		        		mSamples.add([slope,vam]);
		        		mSlope = mSamples.getAverage(0);
		        		mVamSpeed = mSamples.getAverage(1);
		        		mAltitude = mBuffer.getAverage(0);
		        		//System.println("vam: " + mVamSpeed + ", slope: " + mSlope);
		        	}	
		        } 
		    }
	    } else {
	    	mTick++;
	    	mBuffer.push([altitude,location.toDegrees()]);
        }
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
} // end SlopeCalculator

class DataBuffer {

    //! the data array.
    hidden var data;
    hidden var maxSize;
    hidden var startPos;
    hidden var endPos;

    //! precondition: size has to be >= 2
    function initialize(bufferSize) {
        data = new[bufferSize];
        maxSize = bufferSize;
        startPos = 0;  // first element index
        endPos = 0; // first free element index
    }
      
    function push(element) {
        data[endPos] = element;
        endPos = (endPos + 1) % maxSize;
        //System.println("push  (endPos: " + endPos + ",startPos:" + startPos + ") for element " + element + " - " + toString());
    }
    
    function pop() { 
    	//System.println("pop (endPos: " + endPos + ",startPos:" + startPos + ") element " + data[startPos] + " - " + toString());
        var element=null;
        element = data[startPos];
        startPos = (startPos + 1) % maxSize;
        return element;
    }
    
    function add(element) {
    	if (startPos==((endPos+1) % maxSize)) {
    		startPos = (startPos + 1) % maxSize;
    	} 
    	data[endPos]=element;
    	endPos = (endPos+1) % maxSize;
    	//System.println("element Added" + toString());
    }
    
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
    
     function getAverage(idx) {
    	var avg=0;
    	var numValidSamples=0;
    	//System.println("average on buffer : " + toString());
    	if (startPos!=endPos) {
	    	if (startPos<endPos) {
		    	for (var i=startPos; i<endPos;i++) {
		    		avg+=(idx==null ? data[i] : data[i][idx]);
		    		numValidSamples++;		
		    	}
		    } else {
		    	for (var i=startPos; i<endPos+maxSize;i++) {
		    		avg+=(idx==null ? data[i % maxSize] : data[i % maxSize][idx]) ;
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
    
    	return "[startPos=" + startPos + "][endPos=" + endPos + "][" + ret + "]";
    }
    */
}
