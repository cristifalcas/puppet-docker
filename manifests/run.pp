# == Define: docker:run
#
# A define which manages a running docker container.
#
# == Parameters
#
# [*restart*]
# Sets a restart policy on the docker run.
# Note: If set, puppet will NOT setup an init script to manage, instead
# it will do a raw docker run command using a CID file to track the container
# ID.
#
# If you want a normal named container with an init script and a restart policy
# you must use the extra_parameters feature and pass it in like this:
#
#    extra_parameters => ['--restart=always']
#
# This will allow the docker container to be restarted if it dies, without
# puppet help.
#
# [*service_prefix*]
#   (optional) The name to prefix the startup script with and the Puppet
#   service resource title with.  Default: 'docker-'
#
# [*restart_service*]
#   (optional) Whether or not to restart the service if the the generated init
#   script changes.  Default: true
#
# [*restart_service_on_docker_refresh*]
#   Whether or not to restart the service if the docker service is restarted.
#   Only has effect if the docker_service parameter is set.
#   Default: true
#
# [*manage_service*]
#  (optional) Whether or not to create a puppet Service resource for the init
#  script.  Disabling this may be useful if integrating with existing modules.
#  Default: true
#
# [*docker_service*]
#  (optional) If (and how) the Docker service itself is managed by Puppet
#  true          -> Service['docker']
#  false         -> no Service dependency
#  anything else -> Service[docker_service]
#  Default: false
#
# [*extra_parameters*]
# An array of additional command line arguments to pass to the `docker run`
# command. Useful for adding additional new or experimental options that the
# module does not yet support.
#
define docker::run(
  $image,
  $ensure = 'present',
  $command = undef,
  $memory_limit = '0b',
  $cpuset = [],
  $ports = [],
  $labels = [],
  $expose = [],
  $volumes = [],
  $links = [],
  $running = true,
  $volumes_from = [],
  $net = 'bridge',
  $username = false,
  $hostname = false,
  $env = [],
  $env_file = [],
  $dns = [],
  $dns_search = [],
  $lxc_conf = [],
  $service_prefix = 'docker-',
  $restart_service = true,
  $restart_service_on_docker_refresh = true,
  $manage_service = true,
  $docker_service = false,
  $disable_network = false,
  $privileged = false,
  $detach = undef,
  $extra_parameters = undef,
  $extra_systemd_parameters = {},
  $pull_on_start = false,
  $after = [],
  $after_service = [],
  $depends = [],
  $depend_services = [],
  $tty = false,
  $socket_connect = [],
  $hostentries = [],
  $restart = undef,
  $before_start = false,
  $before_stop = false,
  $remove_container_on_start = true,
  $remove_container_on_stop = true,
  $remove_volume_on_start = false,
  $remove_volume_on_stop = false,
  $stop_wait_time = 0,
) {
  include ::docker::params
  if ($socket_connect != []) {
    $sockopts = join(any2array($socket_connect), ',')
    $docker_command = "docker -H ${sockopts}"
  }else {
    $docker_command = 'docker'
  }
  $service_name = 'docker'

  validate_re($image, '^[\S]*$')
  validate_re($title, '^[\S]*$')
  validate_re($memory_limit, '^[\d]*(b|k|m|g)$')
  validate_re($ensure, '^(present|absent)')
  if $restart {
    validate_re($restart, '^(no|always|on-failure|unless-stopped)|^on-failure:[\d]+$')
  }
  validate_string($docker_command)
  validate_string($service_name)
  if $command {
    validate_string($command)
  }
  if $username {
    validate_string($username)
  }
  if $hostname {
    validate_string($hostname)
  }
  validate_bool($running)
  validate_bool($disable_network)
  validate_bool($privileged)
  validate_bool($restart_service)
  validate_bool($restart_service_on_docker_refresh)
  validate_bool($tty)
  validate_bool($remove_container_on_start)
  validate_bool($remove_container_on_stop)
  validate_bool($remove_volume_on_start)
  validate_bool($remove_volume_on_stop)

  validate_integer($stop_wait_time)

  if ($remove_volume_on_start and !$remove_container_on_start) {
    fail("In order to remove the volume on start for ${title} you need to also remove the container")
  }

  if ($remove_volume_on_stop and !$remove_container_on_stop) {
    fail("In order to remove the volume on stop for ${title} you need to also remove the container")
  }

  validate_hash($extra_systemd_parameters)

  if $detach { validate_bool($detach) }
  $valid_detach = $detach

  $extra_parameters_array = any2array($extra_parameters)
  $after_array = any2array($after)
  $depends_array = any2array($depends)
  $depend_services_array = any2array($depend_services)

  $docker_run_flags = docker_run_flags({
    cpuset          => any2array($cpuset),
    detach          => $valid_detach,
    disable_network => $disable_network,
    dns             => any2array($dns),
    dns_search      => any2array($dns_search),
    env             => any2array($env),
    env_file        => any2array($env_file),
    expose          => any2array($expose),
    extra_params    => any2array($extra_parameters),
    hostentries     => any2array($hostentries),
    hostname        => $hostname,
    links           => any2array($links),
    lxc_conf        => any2array($lxc_conf),
    memory_limit    => $memory_limit,
    net             => $net,
    ports           => any2array($ports),
    labels          => any2array($labels),
    privileged      => $privileged,
    socket_connect  => any2array($socket_connect),
    tty             => $tty,
    username        => $username,
    volumes         => any2array($volumes),
    volumes_from    => any2array($volumes_from),
  })

  $sanitised_title = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G')
  if empty($depends_array) {
    $sanitised_depends_array = []
  }
  else {
    $sanitised_depends_array = regsubst($depends_array, '[^0-9A-Za-z.\-]', '-', 'G')
  }

  if empty($after_array) {
    $sanitised_after_array = []
  }
  else {
    $sanitised_after_array = regsubst($after_array, '[^0-9A-Za-z.\-]', '-', 'G')
  }

  if $restart {

    $cidfile = "/var/run/${service_prefix}${sanitised_title}.cid"

    $run_with_docker_command = [
      "${docker_command} run -d ${docker_run_flags}",
      "--name ${sanitised_title} --cidfile=${cidfile}",
      "--restart=\"${restart}\" ${image} ${command}",
    ]
    exec { "run ${title} with docker":
      command     => join($run_with_docker_command, ' '),
      unless      => "${docker_command} ps --no-trunc -a | grep `cat ${cidfile}`",
      environment => 'HOME=/root',
      path        => ['/bin', '/usr/bin'],
      timeout     => 0,
    }
  } else {

    $initscript = "/etc/systemd/system/${service_prefix}${sanitised_title}.service"
    $init_template = 'docker/etc/systemd/system/docker-run.erb'
    $hasstatus = true
    $mode = '0644'
    $uses_systemd = true

    if $ensure == 'absent' {
        service { "${service_prefix}${sanitised_title}":
          ensure    => false,
          enable    => false,
          hasstatus => $hasstatus,
        }

        exec {
          "remove container ${service_prefix}${sanitised_title}":
            command     => "${docker_command} rm -v ${sanitised_title}",
            refreshonly => true,
            onlyif      => "${docker_command} ps --no-trunc -a --format='table {{.Names}}' | grep '^${sanitised_title}$'",
            path        => ['/bin', '/usr/bin'],
            environment => 'HOME=/root',
            timeout     => 0,
        }

    }
    else {
      file { $initscript:
        ensure  => 'file',
        content => template($init_template),
        mode    => $mode,
      }

      if $manage_service {
        if $running == false {
          service { "${service_prefix}${sanitised_title}":
            ensure    => $running,
            enable    => false,
            hasstatus => $hasstatus,
            require   => File[$initscript],
          }
        }
        else {
          # Transition help from moving from CID based container detection to
          # Name-based container detection. See #222 for context.
          # This code should be considered temporary until most people have
          # transitioned. - 2015-04-15
          if $initscript == "/etc/init.d/${service_prefix}${sanitised_title}" {
            # This exec sequence will ensure the old-style CID container is stopped
            # before we replace the init script with the new-style.
            $transition_onlyif = [
              "/usr/bin/test -f /var/run/docker-${sanitised_title}.cid &&",
              "/usr/bin/test -f /etc/init.d/${service_prefix}${sanitised_title}",
            ]
            exec { "/bin/sh /etc/init.d/${service_prefix}${sanitised_title} stop":
              onlyif  => join($transition_onlyif, ' '),
              require => [],
            } ->
            file { "/var/run/${service_prefix}${sanitised_title}.cid":
              ensure => absent,
            } ->
            File[$initscript]
          }

          if $uses_systemd {
            $provider = 'systemd'
          } else {
            $provider = undef
          }

          service { "${service_prefix}${sanitised_title}":
            ensure    => $running,
            enable    => true,
            provider  => $provider,
            hasstatus => $hasstatus,
            require   => File[$initscript],
          }
        }

        if $docker_service {
          if $docker_service == true {
            Service['docker'] -> Service["${service_prefix}${sanitised_title}"]
            if $restart_service_on_docker_refresh == true {
              Service['docker'] ~> Service["${service_prefix}${sanitised_title}"]
            }
          } else {
            Service[$docker_service] -> Service["${service_prefix}${sanitised_title}"]
            if $restart_service_on_docker_refresh == true {
              Service[$docker_service] ~> Service["${service_prefix}${sanitised_title}"]
            }
          }
        }
      }

      if $uses_systemd {
        exec { "docker-${sanitised_title}-systemd-reload":
          path        => ['/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/'],
          command     => 'systemctl daemon-reload',
          refreshonly => true,
          require     => File[$initscript],
          subscribe   => File[$initscript],
        }
        Exec["docker-${sanitised_title}-systemd-reload"] -> Service<| title == "${service_prefix}${sanitised_title}" |>
      }

      if $restart_service {
        File[$initscript] ~> Service<| title == "${service_prefix}${sanitised_title}" |>
      }
      else {
        File[$initscript] -> Service<| title == "${service_prefix}${sanitised_title}" |>
      }
    }
  }
}
