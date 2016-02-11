## Introduction

The open Home Automation Bus (openHAB) project aims at providing a universal integration platform for all things around home automation. It is a pure Java solution, fully based on OSGi.

It is designed to be absolutely vendor-neutral as well as hardware/protocol-agnostic. openHAB brings together different bus systems, hardware devices and interface protocols by dedicated bindings. These bindings send and receive commands and status updates on the openHAB event bus. This concept allows designing user interfaces with a unique look&feel, but with the possibility to operate devices based on a big number of different technologies. Besides the user interfaces, it also brings the power of automation logics across different system boundaries.

For further Information please refer to our homepage [www.openhab.org](http://www.openhab.org). 

## openHAB 2 Distribution

openHAB 2 is the successor of [openHAB 1](https://github.com/openhab/openhab/wiki). It is an open-source solution based on the [Eclipse SmartHome](https://www.eclipse.org/smarthome/) framework. It is fully written in Java and uses [Apache Karaf](http://karaf.apache.org/) together with [Eclipse Equinox](https://www.eclipse.org/equinox/) as an OSGi runtime and bundles this with [Jetty](https://www.eclipse.org/jetty/) as an HTTP server.

openHAB is a highly modular software, which means that the base installation (the "runtime") can be extended through "add-ons". The openHAB distribution includes add-ons from different sources and makes them all available.

![distribution overview](docs/sources/images/distro.png)

Note that the openHAB distribution repository does not contain any source code, but it rather aggregates features from different repos:
 - [Eclipse SmartHome Framework](https://github.com/eclipse/smarthome): This repo holds the major parts of the core functionality.
 - [openHAB 2 Core](https://github.com/kaikreuzer/openhab-core): This repo contains a few small bundles that are not part of Eclipse SmartHome, but required for the openHAB runtime. This e.g. contains a compatibility layer for supporting openHAB 1 add-ons.
 - [openHAB 2 Add-ons](https://github.com/openhab/openhab2): Add-ons of openHAB that use the Eclipse SmartHome APIs can be found within this repository. They cannot be used with an openHAB 1.x runtime, since they provide features that the old runtime does not support.
 - [openHAB 1 Add-ons](https://github.com/openhab/openhab): Add-ons developed for openHAB 1.x. Most of them are working smoothly on the openHAB 2 runtime and thus they are packaged within the distribution. 
 - [Eclipse SmartHome Extensions](https://github.com/eclipse/smarthome/tree/master/extensions): Since openHAB uses the Eclipse SmartHome framework, it is automatically compatible with all extensions that are available for it and maintained within the Eclipse SmartHome repository. These are usually high-quality extensions that might be even used in commercial products.

The distribution is available in two flavors:
 - offline: This package contains all available add-ons and allows installing them locally, i.e. completely offline.
 - online: This package only contains the core runtime and downloads any add-on from a remote repository.

For the latest snapshot builds, please see to our [cloudbees job](https://openhab.ci.cloudbees.com/job/openHAB-Distribution/).

## Getting Started

If you have downloaded the openHAB distribution zip file, simply unzip it to a local folder and call 'start.sh' (resp. 'start.bat') from the command line.
The distribution is preconfigured to install demo files, so that you directly have a working instance that you can start playing with.

Once the runtime is started, you can access it in your browser at 'http://localhost:8080/' (note that it might take a bit for the HTTP server to be started, even if the console already welcomes you):

![dashboard](docs/sources/images/dashboard.png)

From here, you can directly access all web-based user interfaces like the new [Paper UI](docs/sources/features/paperui.md) for administration, as well as the [interactive REST API documentation](https://www.eclipse.org/smarthome/rest/index.html). 

For more details on how to get up to speed, please continue reading the [Getting Started page](docs/sources/getting-started.md).

## Community: How to Get Involved

As any good open source project, openHAB welcomes community participation in the project. Read more in the [how to contribute](CONTRIBUTING.md) guide.

We are trying to maintain a list of [compatible 1.x bindings](docs/sources/addons.md#compatible-1x-add-ons) and [currently incompatible 1.x bindings](docs/sources/addons.md#currently-incompatible-1x-add-ons) in openHAB2. As a user, you can help testing compatibility of 1.x binding in openHAB 2 and then report your results in our [openHAB community](https://community.openhab.org/).

If you are a developer and want to jump right into the sources and execute openHAB from within Eclipse, please have a look at the [IDE setup](docs/sources/development/ide.md) procedures.

You can also learn [how openHAB 2 bindings are developed](docs/sources/development/bindings.md).

In case of problems or questions, please join our vibrant [openHAB community](https://community.openhab.org/).

## Trademark Disclaimer

Product names, logos, brands and other trademarks referred to within the openHAB website are the property of their respective trademark holders. These trademark holders are not affiliated with openHAB or our website. They do not sponsor or endorse our materials.

[![Cloudbees](http://www.cloudbees.com/sites/default/files/Button-Built-on-CB-1.png)](https://openhab.ci.cloudbees.com/job/openHAB-Distribution/)
