//
// Markus Schmidberger, schmidbe@amazon.de
// July 14, 2015
// JavaScript Code to get data from sensor data and to send data to kinesis.
//
//###################
//
// Copyright 2014, Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
// http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
//####################



function printDataValue(input) {
  if( input === undefined )
		return "undefined";
	if( input === null )
		return "null";
	if( input === true )
		return "true";
	if( input === false )
		return "false";
	if( Object.prototype.toString.call(input) === "[object Number]" )
		return Math.round((input + 0.00001) * 100) / 100; // return to 2 decimal places

	return (input + ""); // force stringify
}



// function to collect data and send it to Kinesis
function init() {
  
  // get AWS credentials from Cognito in eu-west-1
	AWS.config.region = 'eu-west-1'; 
	AWS.config.credentials = new AWS.CognitoIdentityCredentials(
		{ AccountId: '374311255271', IdentityPoolId: 'eu-west-1:b23b2b5b-b1c8-45ff-b7fb-3dd73c8f1466',
		RoleArn: 'arn:aws:iam::374311255271:role/Cognito_IoTSensorDemoUnauth_DefaultRole' });
	AWS.config.credentials.get(function() { 
		console.log("updated aws config with web identity federation:\n", AWS.config.credentials);
		AWS.config.identityId = AWS.config.credentials.identityId; 
		console.log("identityId:", AWS.config.identityId); 
	});

  // region switch to connect with correct Kinesis
  AWS.config.region = "eu-west-1";
  var kinesis = new AWS.Kinesis();
	//console.log(kinesis)
  var sregion = document.getElementById("sregion");
  sregion.textContent = printDataValue(AWS.config.region);
	
  // empty object for records
	var records=[];
	
	// object for cognito ID
	var cognitoId = document.getElementById("cognitoId");
	
	// object for device type	
	var device = document.getElementById("device");
	device.textContent = printDataValue(navigator.platform);
	
	// object for moving HTML 5 logo
	var logo = document.getElementById("imgLogo");

	// objects for Device Orientation
	var screenAlpha = document.getElementById("screenAlpha");
	var screenBeta = document.getElementById("screenBeta");
	var screenGamma = document.getElementById("screenGamma");

	// Start FULLTILT DeviceOrientation listeners and register our callback
	var deviceOrientation = FULLTILT.getDeviceOrientation({'type': 'world'});
	deviceOrientation.then(function(orientationData) {	

		orientationData.listen(function() {
			
			cognitoId.textContent = printDataValue(AWS.config.credentials.identityId);

			// Display calculated screen-adjusted deviceorientation
			var screenAdjustedEvent = orientationData.getFixedFrameEuler();

			screenAlpha.textContent = printDataValue(screenAdjustedEvent.alpha);
			screenBeta.textContent = printDataValue(screenAdjustedEvent.beta);
			screenGamma.textContent = printDataValue(screenAdjustedEvent.gamma);
			
			screenAlpha.KinesisContent = screenAdjustedEvent.alpha;
			screenBeta.KinesisContent = screenAdjustedEvent.beta;
			screenGamma.KinesisContent = screenAdjustedEvent.gamma;
			
			// transform HTML 5 object
			logo.style.webkitTransform = "rotate("+ screenAdjustedEvent.gamma +"deg) rotate3d(1,0,0, "+ (screenAdjustedEvent.beta*-1)+"deg)";
			logo.style.MozTransform = "rotate("+ screenAdjustedEvent.gamma +"deg)";
			logo.style.transform = "rotate("+ screenAdjustedEvent.gamma +"deg) rotate3d(1,0,0, "+ (screenAdjustedEvent.beta*-1)+"deg)";
			
		});

	});

	var screenAccGX = document.getElementById("screenAccGX");
	var screenAccGY = document.getElementById("screenAccGY");
	var screenAccGZ = document.getElementById("screenAccGZ");

	// Start FULLTILT DeviceMotion listeners and register our callback
	var deviceMotion = FULLTILT.getDeviceMotion();
	deviceMotion.then(function(motionData) {

		motionData.listen(function() {

			// Display calculated screen-adjusted devicemotion
			var screenAccG = motionData.getScreenAdjustedAccelerationIncludingGravity() || {};

			screenAccGX.textContent = printDataValue(screenAccG.x);
			screenAccGY.textContent = printDataValue(screenAccG.y);
			screenAccGZ.textContent = printDataValue(screenAccG.z);
			
			screenAccGX.KinesisContent = screenAccG.x;
			screenAccGY.KinesisContent = screenAccG.y;
			screenAccGZ.KinesisContent = screenAccG.z;

		});
		
	});
	
	
    // create JSON objec to put into kinesis
	function CreateKinesisInput() {
		
		var cT = new Date().getTime()/1000;
		
		if(AWS.config.credentials.identityId != null)
		{
			var jsonstrOrientation ='{"recordTime":'+cT+',"cognitoId":"'+AWS.config.credentials.identityId+'","device":"'+navigator.platform+'","sensorname":"screenAdjustedEvent","alpha":'+screenAlpha.KinesisContent+', "beta":'+screenBeta.KinesisContent+', "gamma":'+screenGamma.KinesisContent+'}';
			records.push({
		  	  Data: jsonstrOrientation,
				PartitionKey: "screenAdjustedEvent"
			})

			var jsonstrMotion = '{"recordTime":'+cT+',"cognitoId":"'+AWS.config.credentials.identityId+'","device":"'+navigator.platform+'","sensorname":"screenAccG","x":'+screenAccGX.KinesisContent +', "y":'+screenAccGY.KinesisContent +', "z":'+screenAccGZ.KinesisContent +'}';
			records.push({
		  	  Data: jsonstrMotion,
				PartitionKey: "screenAccG"
			})
	
		}

        // set timeout to collect data every dt-time
	    setTimeout(function(){CreateKinesisInput()}, 1000/3);
		

	}
	CreateKinesisInput();	
	
  
  // send records object to kinesis
	function SendKinesis() {

		if(records.length > 0) {
			var params = {
 				Records: records,
 	 	    	StreamName: 'IoTSensorDemo'
			};
			kinesis.putRecords(params, function(err, data) {
 				if (err) console.log(err, err.stack); // an error occurred
 				 //else     console.log(data);           // successful response
			});
			records=[];
		}

   	setTimeout(function(){SendKinesis()}, document.getElementById("update").value*1000);

	}
	SendKinesis();
	


}
