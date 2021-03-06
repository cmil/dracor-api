# dracor-api

The [eXistdb](http://exist-db.org/) application providing the API for
https://dracor.org.

API Documentation is available at [/documentation/api/](https://dracor.org/documentation/api/).

## tl;dr

Use `ant` to build a xar package or `ant devel` to set up a development
environment. Both commands can be used together with `-Dtestdracor=true` to
initialize a small set of data for testing purposes.

## Requirements

- ant
- bash
- (node)

For the calculation of network statistics *dracor-api* depends on the external
[dracor-metrics](https://github.com/dracor-org/dracor-metrics) service. To
(install and) run this service with `ant devel` [Node.js](https://nodejs.org)
(and `npm`) needs to be available.

## Build

This software uses `ant` to build its artifacts. While several targets are
exposed, the following ones are considered to be useful:

- xar [default]
- devel
- cleanup

**Note:** Path and file names mentioned here refer to the default settings in
[build.properties](build.properties). Those can be overwritten in a private
`local.build.properties` file.

### xar

Creates an [EXPath](http://expath.org/spec/pkg) package in the `build`
directory.

When run with the `testdracor` parameter (`ant xar -Dtestdracor=true`) the
package is built with a modified `corpora.xml` file that includes only the
[TestDraCor](https://github.com/dracor-org/testdracor) corpus. This is useful
for testing purposes.

### devel

Sets up a development environment inside the `devel` directory. If this
directory is present, the process will fail. Please remove it yourself.

This target will do the following in this order:

- xar, see above
- download and extract a specified version of eXist-db
- download all dependencies and place them in the `autodeploy` directory
- set the http and https port of this instance (see [build.properties](build.properties))
- start the database once to install all dependencies
  - this step is required to set up the sparql package as it requires a change
  in the configuration file of eXist to be made after the installation
  - the database will shut down immediately
- look for a running instance of the [metrics service](https://github.com/dracor-org/dracor-metrics) on `localhost:8030`
  - if it is not available, it will be installed to the `devel` directory
  and started
  - the process will be [spawned](https://ant.apache.org/manual/Tasks/exec.html)

Afterwards you can start the database with
```bash
bash devel/eXist-db-4.5.0/bin/startup.sh
```

### cleanup

Removes the `devel/` and the `build/` directory.

## Installation

You can install the XAR package built with `ant xar` via the dashboard of any
eXist DB instance.

For development purposes use `ant devel`.
