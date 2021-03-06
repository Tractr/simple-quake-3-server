/**
 * Main application routes
 */

'use strict';

import errors from './errors';
import rconRoutes from './rcon';
import mapsRoutes from './maps';

import expressHealthCheck from 'express-healthcheck';

export default function (app) {
	// Insert routes below

	app.use('/api/rcon', rconRoutes);
	app.use('/api/maps', mapsRoutes);

	app.use('/api/healthcheck', expressHealthCheck());

	// All other routes should redirect to the index.html
	app.route('/*').get(errors[404]);
}
