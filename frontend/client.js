const ipc = require('electron').ipcRenderer;
const fs = require("fs");

$(document).ready(function() {
	$('#exit').click(function() {
       window.close();
	});
});
