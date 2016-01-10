# Setting up an IDE for openHAB

If you are a developer yourself, you might want to setup a development environment, so that you can debug and develop openHAB yourself.

Note that the project build is completely mavenized - so running "mvn install" on any repository root will nicely build all artifacts. For development and debugging, we recommend using an Eclipse IDE though. It should be possible to use other IDEs (e.g. NetBeans or IntelliJ), but you will have to work out how to resolve OSGi dependencies etc. yourself. So unless you have a strong reason to go for another IDE, we recommend using Eclipse.

## Prerequisites

Make sure that you have the following things installed on your computer:

Please ensure that you have the following prerequisites installed on your machine:

1. [Git](https://git-scm.com/downloads)
1. [Maven 3.x](https://maven.apache.org/download.cgi) (optional, Eclipse m2e can also be used)
1. [Oracle JDK 8](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html)

_Note:_ You can find a screencast of the setup process here (note that the options displayed in step 4 have changed meanwhile):

[![Screencast](http://img.youtube.com/vi/o2QjCGdZl7s/0.jpg)](http://www.youtube.com/watch?v=o2QjCGdZl7s)

The Eclipse IDE is used for openHAB developments. The Eclipse Installer automatically prepares the IDE so that it comes with all required plug-ins, the correct workspace encoding settings, pre-configured code formatters and more. Simply follow these steps:

1. Download the [Eclipse Installer](https://wiki.eclipse.org/Eclipse_Installer)
2. Launch the Eclipse Installer and switch to "Advanced Mode" in the top right menu:
![Step 0](images/ide0.png)
3. Choose the "Eclipse IDE for Java Developers" and select "Next":
![Step 1](images/ide1.png)
4. Expand the "Github.com/openHAB" entry, double click "openHAB Development" (the double click is important: The entry has to appear in the empty table at the bottom). Furthermore double-click all entries that you would want to have available in your workspace (you can select multiple/all of them). Make sure that all of them are listed in the table at the bottom and select "Next".
5. Now provide an installation folder (don't use spaces in the path on Windows!) and your Github id (used to push your changesets to) and select "Next".
6. The installation will now begin when pressing "Finish".
7. Once it is done, you will see the Eclipse Welcome Screen, which you can close by clicking "Workbench" on the top right. You will see that the installer not only set up an Eclipse IDE instance for you, but also checked out all selected git repositories and imported all projects into the workspace. 
8. Your workspace should now fully compile and you can start the runtime by launching the "openHAB_Runtime" launch configuration.

Note that you will find the sources in a subfolder called "git" within your selected installation folder. You can use any kind of git client here, if you do not want to use the git support from within the Eclipse IDE.
If you want to push changes, you need to do so to your personal fork of the repository in order to create a pull request. You will find more details in the ["How to contribute"](../../../CONTRIBUTING.md) documentation.
