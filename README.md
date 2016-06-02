_NOTE:_ The official documentation has moved from this repo to [http://docs.openhab.org/](http://docs.openhab.org/)!

## Introduction

The open Home Automation Bus (openHAB) project aims at providing a universal integration platform for all things around home automation. It is a pure Java solution, fully based on OSGi.

It is designed to be absolutely vendor-neutral as well as hardware/protocol-agnostic. openHAB brings together different bus systems, hardware devices and interface protocols by dedicated bindings. These bindings send and receive commands and status updates on the openHAB event bus. This concept allows designing user interfaces with a unique look&feel, but with the possibility to operate devices based on a big number of different technologies. Besides the user interfaces, it also brings the power of automation logics across different system boundaries.

For further Information please refer to our homepage [www.openhab.org](http://www.openhab.org). 

## openHAB 2 Distribution

openHAB 2 is the successor of [openHAB 1](https://github.com/openhab/openhab/wiki). It is an open-source solution based on the [Eclipse SmartHome](https://www.eclipse.org/smarthome/) framework. It is fully written in Java and uses [Apache Karaf](http://karaf.apache.org/) together with [Eclipse Equinox](https://www.eclipse.org/equinox/) as an OSGi runtime and bundles this with [Jetty](https://www.eclipse.org/jetty/) as an HTTP server.

The distribution is available in two flavors:
 - offline: This package contains all available add-ons and allows installing them locally, i.e. completely offline.
 - online: This package only contains the core runtime and downloads any add-on from a remote repository.

For the latest snapshot builds, please see to our [cloudbees job](https://openhab.ci.cloudbees.com/job/openHAB-Distribution/).

## Getting Started

Please refer to [our tutorials](http://docs.openhab.org/tutorials/) on how to get started with openHAB 2.

## Community: How to Get Involved

As any good open source project, openHAB welcomes community participation in the project. Read more in the [how to contribute](CONTRIBUTING.md) guide.

We are trying to maintain a list of [compatible 1.x bindings](http://docs.openhab.org/addons/1xaddons.html) and [currently incompatible 1.x bindings](http://docs.openhab.org/addons/1xaddons.html#currently-incompatible-1x-add-ons) in openHAB2. As a user, you can help testing compatibility of 1.x binding in openHAB 2 and then add missing ones by [creating a PR as explained here](http://docs.openhab.org/developers/development/compatibilitylayer.html#how-to-add-a-successfully-tested-1x-add-on-to-the-distribution).

If you are a developer and want to jump right into the sources and execute openHAB from within Eclipse, please have a look at the [IDE setup](http://docs.openhab.org/developers/development/ide.html) procedures.

You can also learn [how openHAB 2 bindings are developed](http://docs.openhab.org/developers/development/bindings.html).

In case of problems or questions, please join our vibrant [openHAB community](https://community.openhab.org/).

## Trademark Disclaimer

Product names, logos, brands and other trademarks referred to within the openHAB website are the property of their respective trademark holders. These trademark holders are not affiliated with openHAB or our website. They do not sponsor or endorse our materials.

[![Cloudbees](http://www.cloudbees.com/sites/default/files/Button-Built-on-CB-1.png)](https://openhab.ci.cloudbees.com/job/openHAB-Distribution/)
