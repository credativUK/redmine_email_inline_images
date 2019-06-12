# Redmine email inline images plugin

Handle inline images on incoming emails, so that they are included inline in the issue description.

## Features

* Issues created with email requests will include inline images from the email in the issue description.
* When adding attachments to issue, ignore inline images that is truncated.

## Getting the plugin

A copy of the plugin can be downloaded from GitHub: http://github.com/credativUK/redmine_email_inline_images

## Installation

To install the plugin clone the repro from github and migrate the database:

```
cd /path/to/redmine/
git clone git://github.com/credativUK/redmine_email_inline_images.git plugins/redmine_email_inline_images
rake db:migrate_plugins RAILS_ENV=production
```

To uninstall the plugin migrate the database back and remove the plugin:

```
cd /path/to/redmine/
rake db:migrate:plugin NAME=redmine_email_inline_images VERSION=0 RAILS_ENV=production
rm -rf plugins/redmine_email_inline_images
```

Further information about plugin installation can be found at: http://www.redmine.org/wiki/redmine/Plugins

## Compatibility

The latest version of this plugin is only tested with Redmine 2.3.x and 3.3.2.


## License

This plugin is licensed under the GNU GPLv2 license. See LICENSE-file for details.

## Copyright

Copyright (c) 2013 credativ Ltd.

