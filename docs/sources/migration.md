# Migration from openHAB 1 to openHAB 2

There are a few changes in openHAB 2 that you should be aware of, if you are coming from openHAB 1.

Note: This page is work in progress and serves as a place to collect whatever you feel is important to mention when migrating your existing setup to openHAB 2.

## General

 - The Classic UI URL has changed from `/openhab.app` to `/classicui/app`, so you can access your sitemaps at `http://<server>:8080/classicui/app?sitemap=<yoursitemap>`
 - A new default sitemap provider is in place, which provides a dynamic sitemap with the name `_default`, which lists all group items that are not contained within any other group.
 - The `configuration` folder has been renamed to `conf`
 - Instead of the global `configuration/openhab.cfg` file, there is now an individual file per add-on in `conf/services`
 - The OSGi console commands are now available as "smarthome", not as "openhab" anymore.
 - The webapps folder has been discontinued, but static resources can be placed in `conf/html`.
 - It is possible to provide your own custom icons in the `conf/icons/classic` folder - no need to overwrite the icons that come with the runtime

## Rules

In order to continue using rules from openHAB 1, a few minor changes might be necessary:

1. Import statements at the top are not required anymore for any org.openhab package, so these can be removed
1. The state "Uninitialized" has been renamed to "NULL" and thus needs to be replaced in the rules

## Transforms

The **SCALE** transformation has evolved. 
 - Old syntax that was : `[minbound,maxbound]` has to be changed to `[minbound..maxbound]`. 
 - Note that you now have the ability to exclude bounds from the ranges (eg `]minbound..maxbound]`) and also define open ranges : `[minbound..]`
