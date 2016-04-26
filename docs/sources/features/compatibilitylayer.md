# Compatibility Layer for openHAB 1.x Add-ons

openHAB 2 used [Eclipse SmartHome](https://www.eclipse.org/smarthome/) as its core framework. Although many classes are similar, all of them have at least a different namespace (`org.eclipse.smarthome` instead of `org.openhab`) - as a result, none the existing 1.x add-ons would work on openHAB 2.

To still make it possible to use 1.x add-ons, there is a special bundle in openHAB 2, which serves as a compatibility layer. It effectively exposes and consumes all relevant classes and services from the `org.openhab` namespace and internally delegates or proxies them to the according `org.eclipse.smarthome` classes and services.

Currently, the compatibility layer focuses on the official APIs, i.e. an add-ons that does no dirty things should be able to run. Taking the huge number of 1.x add-ons into account, it is likely that there are a couple of problems with one or another. Some problems might be due to bugs in the compatibility bundle, others might be solvable within the add-on.

## How to use openHAB 1.x Add-ons that are not part of the distribution
 
While the openHAB distribution already contains many add-ons of openHAB 1, there are still quite some of them missing - please help testing them - if they are confirmed to be working, they can be included in the distribution.
Test a not included add-on is very straight forward: 
 - Start your runtime
 - Install the 1.x compatibility layer by running `feature:install openhab-runtime-compat1x` in the openHAB console 
 - As with openHAB 1.x, simply take the jar file of your add-on and place it in the `${openhab.home}/addons` folder.
 - Copy your personal `openhab.cfg` file to `${openhab.home}/conf/services/openhab.cfg`.
 
## How to solve problems with a certain add-on?
 
All developers are encouraged to help on this in order to quickly make as many 1.x add-ons compatible with the openHAB 2 runtime as possible.
Here is what you need to do:
 - Setup a the [openHAB 2 IDE](../development/ide.md).
 - Import your 1.x add-on from your local openHAB 1 git clone into your workspace.
 - If it compiles, the first major step is already done. If not, try to figure out why there are compilation problems and if you cannot solve them, ask on the mailing list for help. 
 - After adding some configuration, start up the runtime through the launch configuration (make sure your bundle is activated and started by default) from within the IDE.
 - Go and test and report your findings by creating issues or pull requests for the [add-on in openHAB 1](https://github.com/openhab/openhab/issues).
 
## How to add a successfully tested 1.x Add-on to the distribution
 
1. The first step is to create a "Karaf feature" for it, in which required dependencies (i.e. to io.transport bundles) can also be declared. Such a feature can also include the required configuration, therefore you should create a file `<youraddon>.cfg` in `features/openhab-addons-external/src/main/resources/conf` with the same content as what is within `openhab.cfg`, but without the `<yourbinding>:` prefix on the lines of the parameters. 
This config file then needs to be added to `features/openhab-addons-external/pom.xml` so that the build is aware of it.
The feature itself is then added to `features/openhab-addons/src/main/feature/feature.xml`, referencing the bundle, the config file and its dependencies (if any). The result should look [similar to this](https://github.com/openhab/openhab/pull/3988/files).
This will automatically make the add-on a part of the distro with the next build.
1. Note that with defining a Karaf feature, bindings are available for installation through the Paper UI in the "Extensions" menu, but they are not listed under "Configuration->Bindings" (although it is fully operational after installation). In order to have bindings listed there as well, you need to add some meta-information to the binding bundle. This information should be put into `ESH-INF/binding/binding.xml` and its content is [described here](https://www.eclipse.org/smarthome/documentation/development/bindings/xml-reference.html#xml-structure-for-binding-definitions). Do not forget to add `ESH-INF` to your `build.properties`, so that it is packaged in the bundle. See a [real life example of such meta-data here](https://github.com/openhab/openhab/pull/4271/files).


## Future Plans

Note that the maintenance and support of the 1.x add-ons will continue. There is absolutely no need and no rush to port them to the new 2.x APIs - especially as there are only new APIs for bindings so far, but nothing yet for actions, persistence services or other types of add-ons. Even for bindings you have to be aware that the new APIs are not yet stable and are likely to change over time. Nonetheless, if you [start a completely new binding](../development/bindings.md) for openHAB, you are encouraged to go for openHAB 2 APIs directly - especially, if your devices can be discovered and formally described. A positive side effect of implementing a binding against the new APIs is the fact that your code is potentially automatically compatible with other Eclipse-SmartHome-based systems (of which there will be more in future).
