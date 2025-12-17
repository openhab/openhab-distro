# openHAB Demo App

The openHAB Demo App is designed as a reference implementation and testing environment for openHAB developers.
It provides a sample configuration and runtime that demonstrates key features and integrations of openHAB, making it useful for exploring, developing, or validating extensions and bindings in a controlled environment.

See the [documentation about the demo app](https://www.openhab.org/docs/developer/ide/generic.html).

## Starting the Demo App

You can start the demo app in two ways:
- **From Eclipse:** Launch the app using your IDE.
- **From the command line:**
  ```
  mvn bnd-run:run
  ```

## Troubleshooting Dependencies

If dependencies do not resolve, `launch.bndrun` may need an update.

- Trigger the resolver with:
  ```
  mvn install -DwithResolver
  ```

If this issue occurs on an unmodified install, please [open an issue on GitHub](https://github.com/openhab/openhab-distro/issues).

