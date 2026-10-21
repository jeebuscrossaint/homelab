/* eslint-disable no-undef */
// Overleaf needs Mongo running as a replica set. Runs once, on first start.
rs.initiate({ _id: 'overleaf', members: [{ _id: 0, host: 'mongo:27017' }] })
