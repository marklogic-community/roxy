# Roxy

## Table of Contents
 - [Overview](#overview)
 - [Features](#features)
 - [Getting Help](#getting-help)
 - [Requirements](#requirement)
 - [Quick Start](#quick-start)

## Overview
Roxy is a utility for configuring and deploying MarkLogic applications. Using
Roxy you can define your app servers, databases, forests, groups, tasks, etc
in local configuration files. Roxy can then remotely create, update, and remove
those settings from the command line.

## Features

### Cross Platform
Roxy runs on any platform that runs Ruby. We currently test on Mac, Linux, and Windows.

### Multiple Environments
Roxy supports multiple deployment environments. You can define your own or
use the default environments: local, dev, and prod. Each environment can have
different settings which are specified in properties files or xml config files.

### Easily Create and Deploy REST Extensions
Roxy provides scaffolding for creating REST extensions, transforms, etc. Once
you have writtern your REST extension Roxy makes deploying to the server
a breeze.

### Capture Existing MarkLogic Settings
Whether it's a legacy application or you just prefer to configure
your application using the Admin UI, Roxy can capture existing MarkLogic settings
so that you can use them in your application. This feature is great for backing up
Legacy Servers. Once the configurations are in Roxy you can then deploy to
other servers.

### Backwards Compatible
Roxy works with all supported versions of MarkLogic server out of the box.

### Customization
Roxy is written in Ruby. Simply by editing the app_specific.rb file you can
enhance, override, or replace the default functionality.

### Run as a Java Jar
If you work in an environment where installing [Ruby](http://ruby-lang.org) is not an option you
can [run Roxy as a self contained jar](https://github.com/marklogic/roxy/wiki/Run-Roxy-as-a-Jar) file which embeds [JRuby](http://jruby.org).

## Getting Help
To get help with Roxy,

* Subscribe to the [Roxy mailing list](http://developer.marklogic.com/mailman/listinfo/roxy)
* Read up on [the wiki](https://github.com/marklogic/roxy/wiki)
* Check out the [Tutorials page](https://github.com/marklogic/roxy/wiki/Tutorials)
* For Command line usage run:  
  `$ ml -h`


## Requirements
* A supported version of [MarkLogic](https://github.com/marklogic/roxy/wiki/Supported-MarkLogic-versions)
* [Ruby 1.9.3](http://www.ruby-lang.org/en/) or greater
* [Java (jdk)](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
  Only if you wish to run the [mlcp](http://developer.marklogic.com/products/mlcp), [XQSync](http://developer.marklogic.com/code/xqsync, XQSync), or [RecordLoader](http://developer.marklogic.com/code/recordloader) commands.
* [Git](http://git-scm.com/downloads) - Required to create a new project using "ml new".

## Quick Start
This section describes the quickest way to get started using Roxy.

### Assumptions
* You already have one or more MarkLogic Servers running somewhere that you can access from your computer. If not, get it [here](http://developer.marklogic.com/products).*
* You know the admin logon to your MarkLogic Server(s)

### Get Roxy
Use one of these three options to get started. 

#### Using git
You can download Roxy using git
`$ git clone git://github.com/marklogic/roxy.git`

#### Grab a zipped version
If you prefer to grab the archive simply download the latest release from our [Releases Page](https://github.com/marklogic/roxy/releases)

#### Install the Shell script or Batch File
Roxy comes with a script that you can put in your path. This file will create new projects for you by
by issuing the `$ ml new` command. Grab one of these files and put it in a folder in your PATH.
*__Note:__ In order for `$ ml new` to work you need to have git installed.*

##### Windows
Download the [ml.bat](https://github.com/marklogic/roxy/raw/master/ml.bat) file

##### Mac/Linux
Download the [ml](https://github.com/marklogic/roxy/raw/master/ml) file

### Configure your application
1. Open a command prompt in the root folder of Roxy.
2. Run ml init to create sample configuration files.  
  *You must specify the --server-version option with a value of 6, 7, or 8*.  
  *You must specify the --app-type with a value or bare, rest, hybrid, or mvc*.

  `$ ml init app-name --server-version=7 --app-type=rest`
3. Modify deploy/build.properties with your application's settings.

```
# Username to authenticate to ML
user=your-ml-admin-username

# password for ML authentication
#
# leave this blank to be prompted for your password
#
password=

# the authentication type for the appserver (digest|basic|application-level)
authentication-method=application-level

# the default user to authenticate with. defaults to nobody
default-user=${app-name}-user

# Specify the server(s) you wish to deploy to here. This tutorial assumes you are using localhost.
local-server=localhost
#dev-server=
#prod-server=
```

### Configure MarkLogic Server
*This step is only needed when database configurations have changed or on a fresh install. In most cases you will not need to restart your server.*

1. Open a command prompt in the root folder of Roxy.  
  *If your server is not configured as local-server in build.properties then substitute your environment here __( local | dev | prod )__*
2. `$ ml local bootstrap`
3. Depending on what changed you may need to restart MarkLogic in order to proceed. If you see output telling you to restart...  
  `$ ml local restart`

### Deploying Code
*This step describes how to deploy your Roxy application into your MarkLogic Server modules database. If you have elected to run your code locally out of the filesystem you do not need to do this.*

1. Open a command prompt in the root folder of Roxy
2. `$ ml local deploy modules`

### Congratulations
**Congratulations!** You have Roxy running on your server. Now you need to start customizing it.
