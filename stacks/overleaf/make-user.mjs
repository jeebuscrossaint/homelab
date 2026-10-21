// install.sh pipes this into the overleaf container (run from /overleaf/services/web).
// Makes the one admin user that latex.lab signs you in as, with the password from .env.
import crypto from 'node:crypto'
import UserGetter from './app/src/Features/User/UserGetter.mjs'
import UserRegistrationHandler from './app/src/Features/User/UserRegistrationHandler.mjs'
import AuthenticationManager from './app/src/Features/Authentication/AuthenticationManager.mjs'
import { User } from './app/src/models/User.mjs'

const { OVERLEAF_EMAIL: email, OVERLEAF_PASSWORD: password } = process.env

let user = await UserGetter.promises.getUserByAnyEmail(email)
if (user) {
	try {
		await AuthenticationManager.promises.setUserPassword(user, password)
	} catch (err) {
		// already that password (every install.sh run after the first)
		if (err.name !== 'PasswordMustBeDifferentError') throw err
	}
} else {
	user = await UserRegistrationHandler.promises.registerNewUser({
		email,
		password,
		analyticsId: crypto.randomUUID(),
	})
}
await User.updateOne({ _id: user._id }, { $set: { isAdmin: true } }).exec()
process.exit(0)
