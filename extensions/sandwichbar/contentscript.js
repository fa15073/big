// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

var phoneNames = ["iPhone 6", "iPhone 6 Plus"];
var storeNumbers = ["R119", "R224", "R079"];
var phoneColorClasses = ["iPhone6", "iPhone6Plus"];

var context = {
	storeNumber: 0,
	phoneName: 0,
	phoneColor: 0,
};

var main = function() {
 
	var myEvent = document.createEvent('Event');
	myEvent.initEvent('CustomEvent', true, true);

	function fireCustomEvent() {
		document.body.dispatchEvent(myEvent);
	};

	jQuery(document).ajaxComplete(function(event,request, settings){
		console.log("Ajax complete.");
		fireCustomEvent();
	});
};
 
// Lets create the script objects
var injectedScript = document.createElement('script');
injectedScript.type = 'text/javascript';
injectedScript.text = '('+main+')("");';
(document.body || document.head).appendChild(injectedScript);

document.body.addEventListener('CustomEvent', function() {
	console.log("Received event!");
	context.phoneColor = (context.phoneColor + 1) % 3;
	if (context.phoneColor === 0){
		context.phoneName = (context.phoneName + 1) % 2;
	}

	if (context.phoneName === 0 && context.phoneColor === 0){
		context.storeNumber = (context.storeNumber + 1) % 3;
	}

    if ($("#100015").css("display") === "block" &&
    	$("input[name='selectedPartNumber'][disabled]").length == 3) {
    	setTimeout(start, Math.random() * 5000 + 4000);
    } else {
    	chrome.extension.sendRequest({count: 1}, function(response) {});
    }
});

var regex = /sandwich/gi;
matches = document.body.innerText.match(regex);
if (matches) {
  var payload = {
    count: matches.length    // Pass the number of matches back.
  };
  chrome.extension.sendRequest(payload, function(response) {});
}

function start()
{
	$("select[name='selectedStoreNumber']").val(storeNumbers[context.storeNumber]);
	$("input[value='" + phoneNames[context.phoneName] + "']").click();
	$("input[value='UNLOCKED']").click();
	$("input[name='color']." + phoneColorClasses[context.phoneName])[context.phoneColor].click();
}