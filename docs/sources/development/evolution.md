# Technical Difference to openHAB 1
 
There are a few changes in openHAB 2 that you should be aware of, if you are coming from openHAB 1:

 - the Classic UI URL has changed from `/openhab.app` to `/classicui/app`, so you can access your sitemaps at `http://<server>:8080/classicui/app?sitemap=<yoursitemap>`
 - a new default sitemap provider is in place, which provides a dynamic sitemap with the name `_default`, which lists all group items that are not contained within any other group.
 - the `configuration` folder has been renamed to `conf`
 - instead of the global `configuration/openhab.cfg` file, there is now an individual file per add-on in `conf/services`
 - The OSGi console commands are now available as "smarthome", not as "openhab" anymore.
 - the REST API does NOT support XML nor JSON-P anymore. It is now fully realized using JSON.
 - the REST API does not support websocket access anymore - it actually completely drops "push" support and only has a simple long-polling implementation to provide a basic backward-compatibility for clients. 
 - The webapps folder has been discontinued, but static resources can be placed in `conf/html`.
 - It is possible to provide your own custom icons in the `conf/icons/classic` folder - no need to overwrite the icons that come with the runtime
 - the rule syntax has slightly changed, you e.g. do not need import statements anymore for the most common classes (see the [Migration Guide](../migration.md) for details). At the same time, there is no openHAB Designer anymore, but the Eclipse SmartHome designer can be used. 
