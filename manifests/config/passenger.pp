# Configure the foreman service using passenger
class foreman::config::passenger (
  # specifiy which interface to bind passenger to eth0, eth1, ...
  $listen_on_interface = '',
  $scl_prefix = undef
) {

  $ssl_cert  = $foreman::vhost_ssl_cert
  $ssl_key   = $foreman::vhost_ssl_key
  $ssl_ca    = $foreman::vhost_ssl_ca
  $ssl_chain = $foreman::vhost_ssl_ca

  # validate parameter values
  validate_string($listen_on_interface)

  include apache

  # Check the value in case the interface doesn't exist, otherwise listen on all interfaces
  if $listen_on_interface in split($::interfaces, ',') {
    $listen_interface = inline_template("<%= @ipaddress_${listen_on_interface} %>")
  } else {
    $listen_interface = undef
  }

  # Set up passenger
  include ::passenger

  if $scl_prefix {
    class {'::passenger::scl':
      prefix => $scl_prefix,
    }
  }

  # Workaround so apache::vhost doesn't attempt to create a directory
  file {"${foreman::app_root}/public": }

  Apache::Vhost {
    ip            => $listen_interface,
    servername    => $::fqdn,
    serveraliases => ['foreman'],
    docroot       => "${foreman::app_root}/public",
    priority      => '5',
    options       => ['none'],
    require       => Class['foreman::install'],
  }

  if $foreman::use_vhost {
    apache::vhost { 'foreman':
      port            => 80,
      custom_fragment => template('foreman/apache-fragment.conf.erb'),
    }
  } else {
    file { 'foreman_vhost':
      path    => "${foreman::apache_conf_dir}/foreman.conf",
      content => template('foreman/foreman-apache.conf.erb'),
      mode    => '0644',
      notify  => Service['httpd'],
      require => Class['foreman::install'],
    }
  }

  if $foreman::ssl {
    apache::vhost { 'foreman-ssl':
      port            => 443,
      ssl             => true,
      ssl_cert        => $ssl_cert,
      ssl_key         => $ssl_key,
      ssl_ca          => $ssl_ca,
      ssl_chain       => $ssl_chain,
      custom_fragment => template('foreman/apache-fragment.conf.erb', 'foreman/apache-fragment-ssl.conf.erb'),
    }
  }

  file { ["${foreman::app_root}/config.ru", "${foreman::app_root}/config/environment.rb"]:
    owner   => $foreman::user,
    require => Class['foreman::install'],
  }
}
