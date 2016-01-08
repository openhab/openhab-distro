# Getting Started with openHAB 2

_Note: This guide assumes that you are already familiar with the general concepts of openHAB 1 and hence focuses on what is different in openHAB 2. If you are a newbie to openHAB, you should rather go with openHAB 1 or at least refer to [its documentation](https://github.com/openhab/openhab/wiki/Configuring-the-openHAB-runtime)._

## Installation

openHAB comes as a [platform independent zip file](https://openhab.ci.cloudbees.com/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-offline/target/openhab-offline-2.0.0-SNAPSHOT.zip), which you only need to extract to some folder.

You will find the following folders:
 - `conf`: This contains all your user specific configuration files.
 - `runtime`: This contains the openHAB binaries, there should normally be no need to touch anything in here - the whole folder can be considered to be read-only.
 - `userdata`: Here you will find all the data that is generated during runtime: log files, database files, etc. In theory this should be the only folder where openHAB needs write permission on.
 - `addons`: Here you can drop add-ons (or any other OSGi bundles) that you want to be deployed in your instance. These can be add-ons for openHAB 1.x and 2.x likewise. Note that all "normal" add-ons are already included in the openHAB distribution and all you need is to name them in your 'addons.cfg' file (see below). Hence the `addons` folder is mainly useful if you have received jars from other sources and want to install and test them. 
 
## Choosing a Base Package and Add-ons to be Installed 

If you do not do any changes to the distribution, it will by default install a demo package, which consists out of demo configuration file (for items, sitemaps, etc.) and a selection of add-ons and UIs.

If you do not want the demo package, you should directly edit the file 'conf/services/addons.cfg'.
It allows you to choose a base package and any add-on that you might want to install. Note that all required dependencies (e.g. io.transport bundles) will automatically be installed, so you do not need to worry about this anymore. You also do not have to get hold of the jar file yourself as the openHAB distribution either includes it already locally (offline distro) or knows from where to download it (online distro).

```
# The base installation package of this openHAB instance
# Valid options:
#   - minimal  : Installation only with dashboard, but no UIs or other addons
#   - standard : Typical installation with all standards UIs
#   - demo     : A demo setup which includes UIs, a few bindings, config files etc.
package = standard

# A comma-separated list of bindings to install (e.g. "sonos,knx,zwave")
binding = knx,sonos,http

# A comma-separated list of UIs to install (e.g. "basic,paper")
ui = paper,basic

# A comma-separated list of persistence services to install (e.g. "rrd4j,jpa")
persistence = rrd4j

# A comma-separated list of actions to install (e.g. "mail,pushover")
action =

# A comma-separated list of transformation services to install (e.g. "map,jsonpath")
transformation = map

# A comma-separated list of text-to-speech engines to install (e.g. "marytts,freetts")
tts =

# A comma-separated list of miscellaneous services to install (e.g. "myopenhab")
misc = myopenhab
```  

Many add-ons require some configuration. In openHAB 1.x, this was done in the central `openhab.cfg` file. In openHAB 2.x this has changed to separate files in the folder `conf/services`, e.g. the add-on 'acme' is configured in the file `conf/services/acme.cfg`.
 
Likewise, the syntax in the configuration files has changed to not require the namespace anymore, i.e. instead of
```
acme:host=192.168.0.2
```
in `openhab.cfg` you would now simply enter
```
host=192.168.0.2
```
in the `acme.cfg` file.

If an add-on provides configuration options, the according cfg file will be automatically created in `conf/services`, when installing the add-on (as long as the `conf` folder is writable for openHAB).

## Starting the Runtime

Once you have configured your runtime, you can simply start openHAB by calling `start.sh` resp. `start.bat` on Windows. Point your browser to ```http://<hostname>:8080``` (allow the runtime some time to start before the HTTP server is available, especially on the very first start) and you will be welcomed by the openHAB Dashboard.

Logfiles are written to `userdata/logs`, so please check these in case of any problem.

## Using the Shell

openHAB uses Apache Karaf and thus comes with a very powerful shell for managing the installation. Please check the [Karaf command reference](http://karaf.apache.org/manual/latest/commands/commands.html) for details. Useful commands e.g. include:

 - `log:tail`: Show the live logging output, end it by pressing ctrl+c.
 - `log:exception-display`: Show the last exception of the log file.
 - `log:set DEBUG org.openhab.binding.sonos`: Enables debug logging for a certain binding.
 - `feature:list`: Lists all features available and shows there status. openHAB add-ons are made available as such Karaf features.
 - `feature:install openhab-binding-knx`: Installs a certain add-on (here KNX). 
 - `bundle:list -s`: Lists all installed bundles with their symbolic name.
 - `logout`: Shuts down openHAB.
 
## Registering openHAB as a System Service in the OS

Karaf provides the possibility to be automatically started on system startup as a service. As different mechanisms are required for the different operating systems, Karaf detects your OS and generates the required files. To do so, simply call
```
openhab:install-service 
```
in the shell and make sure that the folder `<openhab root folder>/runtime/karaf` is writable (only required at this time, you can make it read-only again afterwards).
The files are then generated for you and a short guide is displayed on what further actions you need to take to register it as a system service.
