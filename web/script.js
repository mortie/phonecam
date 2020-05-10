let $ = document.querySelector.bind(document);

let connectForm = $("#connect-form");
let connectBtn = $("#connect-btn");

async function api(path, obj = {}) {
	let res = await fetch(path, {
		method: "POST",
		body: JSON.stringify(obj)
	}).then(res => res.json());

	if (res.error != null) {
		alert(res.error);
		throw new Error(res.error);
	}

	return res;
}

async function delay(ms) {
	return new Promise((resolve, reject) => {
		setTimeout(resolve, ms);
	});
}

async function startStream() {
	try {
		let stream = await navigator.mediaDevices.getUserMedia({ video: true });
	} catch (err) {
		if (err.name == "NotFoundError") {
			alert("No camera devices found.");
		} else {
			alert("Error "+ err.name + ": " + err.message);
		}

		throw err;
	}
}

async function onEvent(evt) {
	switch (evt.type) {
	case "start-stream":
		await startStream();
		break;
	}
}

async function connect() {
	await api("/api/connect");

	while (true) {
		await delay(100);
		let events = await api("/api/poll");

		for (event of events) {
			console.log(event);
			try {
				await onEvent(event);
			} catch (err) {
				await api("/api/disconnect");
				throw err;
			}
		}
	}
}

connectForm.addEventListener("submit", async e => {
	e.preventDefault();
	connectBtn.disabled = true;
	try {
		await connect();
	} catch (err) {
		console.error(err);
		connectBtn.disabled = false;
	}
});
