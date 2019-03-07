# Powerup

## About


Powerup is a tool for building reports and helping to write automated tasks. Primarily intended for SQL Server and Sybase DBAs.

Powerup is written in Powershell v2 and it's recommended that .NET 3.5 is installed.

Features:

- Online documentation
- Works with Windows 2008 onwards
- Powershell v2 is enought to run most of the scripts
- Portable installation: everything needed is bundled in one convenient package
- Extensible: adding or replacing modules is simple
- Unit tested: supports unit testing coverage with [Pester](https://github.com/pester/Pester)

## Quick Installation

Or **Clone** this repository and run (bash only sorry):

```
# Full version (bigger with additional assemblies)
bash pack.sh -A -o DESTINATION_DIR

# Lite version
bash pack -o DESTINATION_DIR
```

Copy the zip package file to your server, unzip the file on any directory of your choosing
(we'll use __C:\Powerup__ in the examples) and execute __StartHere.cmd__

I recommend running __Invoke-Tests__ to run the test suite and see if everything is working.


**LOCALDIR: Site specific configuration**

It's a **very** good idea to have a separate directory for local customizations, configuration, reports, etc. You also get ready to use example scripts.

You can install with __Install-Localdir__. In this example we use __C:\Local__ but it can be any directory other than where you installed powerup.

```
# create a site specific dir
mkdir C:\Local
Install-Localdir C:\Local
exit
```

After installing local directory, you need to start using __launcher.cmd__ or __launcher_x86.cmd__ on the new directory.

You might want to edit to customize some of the config files. Check the wiki for more detailed instructions.


## Config

If you are using a Localdir you may edit any of the shipped config files with __Edit-Config__. 

It's recommended at least to edit these 

```
# For session path, and defaults
Edit-Config defaults

# If you are sending emails, you need to set parameters with
Edit-Config address
Edit-Config smtp
```

After editing any config run you may run __Test-Config__ to check for syntax errors.

For more information check Config on the wiki.

## Upgrade

To upgrade to a new version follow installation instructions (you may use another directory, or delete the old version).

If you have a local directory you need to update it. There are two ways to do this:
 
Open a new session with __StartHere.cmd__ on the new version:
```
# Update your existing localdir (eg. C:\Local)
Install-Localdir C:\Local
```

Using your current session, load the new version in place:
```
# Rebase your working powerup version (eg C:\powerup)
Rebase-Powerup  C:\Powerup
````


## Usage


Get online help

```
help about_Powers
help about_Topics
help about_Hier
help about_Config
help about_Modules
```

Import modules

```
Import-Power 'Windows.Uptime'

# Use is an alias for Import-Power
use 'Windows.Uptime'
```


If you have a local dir, check example scripts on it's __invoke__ directory.


## Copying

Apache 2 License

