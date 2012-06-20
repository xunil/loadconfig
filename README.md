# Introduction
I needed a tool to call from a shell script which could generate new configuration statements for Juniper devices, based on existing config, and load the new configuration to the devices automatically.  This tool fits the bill; uses <code>net/ssh</code>, <code>REXML</code>, <code>Erubis</code>, and my own cobbled-together object for interacting with JunOScript.

Pass it SSH credentials, a hostname, and an Erubis template.  The <code>REXML::Document</code> object <code>current_config</code> is available from within the template; perform XPath searches (or walk the document) to access the existing configuration.  This makes it much easier to build config changes.

<pre>
Usage: loadconfig [options]
    -u, --username=USERNAME          Juniper username
    -p, --password=PASSWORD          Juniper password
    -k, --ssh-key=KEYFILE            Juniper SSH key filename
    -H, --hostname=HOSTNAME          Hostname of Juniper device
    -f, --filename=FILENAME          Filename of configuration snippet to load
    -n, --dryrun                     Verify configuration commit would succeed but do not commit
    -d, --debug                      Output JunOScript interactions
    -h, --help                       Display usage message
</pre>

# License
Released under the MIT license.  See the file LICENSE.
