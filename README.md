This repos is archived. Please use https://github.com/utking/puppet-docker from now on.


# docker
[![Build Status](https://travis-ci.org/cristifalcas/puppet-docker.png?branch=master)](https://travis-ci.org/cristifalcas/puppet-docker)

Puppet module for installing, configuring and managing [Docker](https://github.com/dotcloud/docker)

This module was forked from https://github.com/garethr/garethr-docker.git and modified to only work with
the docker package from centos.

## Support

This module is currently only for RedHat clones 7.x:

* Centos 7.0
* OracleLinux 7.0
* RedHat 7.0


## Usage

The module includes a single class:

```puppet
include 'docker'
```

By default the docker daemon will bind to a unix socket at
/var/run/docker.sock. This can be changed, as well as binding to a tcp
socket if required.

```puppet
class { 'docker':
  bind_to    => 'tcp://127.0.0.1:4243',
}
```

If you want to track the latest version you can do so:

```puppet
class { 'docker':
  version => 'latest',
}
```


In some cases dns resolution won't work well in the container unless you give a dns server to the docker daemon like this:

```puppet
class { 'docker':
  dns => '8.8.8.8',
}
```

The class contains lots of other options, please see the inline code
documentation for the full options.

### Images

The next step is probably to install a docker image; for this we have a defined type which can be used like so:

```puppet
docker::image { 'base': }
```

This is equivalent to running `docker pull base`. This is downloading a large binary so on first run can take a while. For that reason this define turns off the default 5 minute timeout for exec. Takes an optional parameter for installing image tags that is the equivalent to running `docker pull -t="precise" ubuntu`:

```puppet
docker::image { 'ubuntu':
  image_tag => 'precise'
}
```

Note: images will only install if an image of that name does not already exist.

A images can also be added/build from a dockerfile with the `docker_file` property, this equivalent to running `docker build -t ubuntu - < /tmp/Dockerfile`

```puppet
docker::image { 'ubuntu':
  docker_file => '/tmp/Dockerfile'
}
```

Images can also be added/build from a directory containing a dockerfile with the `docker_dir` property, this is equivalent to running `docker build -t ubuntu /tmp/ubuntu_image`

```puppet
docker::image { 'ubuntu':
  docker_dir => '/tmp/ubuntu_image'
}
```

You can also remove images you no longer need with:

```puppet
docker::image { 'base':
  ensure => 'absent'
}

docker::image { 'ubuntu':
  ensure    => 'absent',
  image_tag => 'precise'
}
```

If using hiera, there's a `docker::images` class you can configure, for example:

```yaml
docker::images:
  ubuntu:
    image_tag: 'precise'
```


### Private registries
By default images will be pushed and pulled from [index.docker.io](http://index.docker.io) unless you've specified a server. If you have your own private registry without authentication, you can fully qualify your image name. If your private registry requires authentication you may configure a registry:

```puppet
docker::registry { 'example.docker.io:5000':
  username => 'user',
  password => 'secret',
  email    => 'user@example.com',
}
```

You can logout of a registry if it is no longer required.

```puppet
docker::registry { 'example.docker.io:5000':
  ensure => 'absent',
}
```

If using hiera, there's a docker::registry_auth class you can configure, for example:

```yaml
docker::registry_auth::registries:
  'example.docker.io:5000':
    username: 'user1'
    password: 'secret'
    email: 'user1@example.io'
```

