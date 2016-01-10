# Technical Difference to openHAB 1
 
There are a few technical changes in openHAB 2 that are not compatible with openHAB 1:

 - the REST API does NOT support XML nor JSON-P anymore. It is now fully realized using JSON.
 - the REST API does not support websocket access anymore - it actually completely drops "push" support and only has a simple long-polling implementation to provide a basic backward-compatibility for clients. 
