const electron = require('electron');
const ipc = electron.ipcMain;
const {
	app,
	BrowserWindow,
	Menu
} = require('electron');
const fs = require("fs");

let mainWindow;

function LOG_TERM(data) {
	console.log(data);
	mainWindow.webContents.send('log_term', {
		msg: data
	});
	fs.appendFile(logfile, data + "\n", function (err) {});
}

app.on('window-all-closed', () => {
	if (process.platform != 'darwin')
		app.quit();
});

app.on('ready', function() {
	mainWindow = new BrowserWindow({
		width: 930,
		height: 930,
		title: "",
		icon: __dirname + '/icon.png',
		resize: true,
		frame: false
	});

	mainWindow.loadURL('file://' + __dirname + '/index.html');
	mainWindow.focus();

	var application_menu;

	application_menu = [{
		label: '&File',
		submenu: [{
			label: 'Exit',
			click: () => {
				app.quit();
			}
		}]
	}, ];

	menu = Menu.buildFromTemplate(application_menu);
	Menu.setApplicationMenu(menu);

	//For debugging:
	//mainWindow.webContents.openDevTools();

	mainWindow.on('closed', function() {
		mainWindow = null;
	});
});
