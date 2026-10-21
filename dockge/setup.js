// install.sh pipes this into the dockge container (run from /app).
// Makes the one user with the password from .env, then turns off the login screen.
const { io } = require("socket.io-client");

const username = "me";
const password = process.env.DOCKGE_PASSWORD;
const socket = io("http://localhost:5001", { transports: ["websocket"] });
const emit = (...args) => new Promise((resolve) => socket.emit(...args, resolve));

socket.on("connect", async () => {
	// fails once a user exists (every install.sh run after the first), which is fine
	await emit("setup", username, password);
	const login = await emit("login", { username, password });
	if (!login.ok) fail(login.msg);
	const saved = await emit("setSettings", { disableAuth: true }, password);
	if (!saved.ok) fail(saved.msg);
	process.exit(0);
});
socket.on("connect_error", (err) => fail(err.message));
setTimeout(() => fail("timed out"), 20000);

function fail(msg) {
	console.error(msg);
	process.exit(1);
}
