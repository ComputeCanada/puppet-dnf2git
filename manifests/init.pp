class dnf2git (
  String $prefix = '/opt/software',
  String $subdirectory = '',
  String $domain = '',
  String $branch = 'main',
  String $gitlab_token,
  String $gitlab_repository,
  String $gitlab_url,
) {
  $software_list_generator_prefix = "$prefix/software_list_generator_env"
  uv::venv { 'software_list_generator_env':
    prefix       => $software_list_generator_prefix,
    python       => '3.13',
    requirements => 'python-gitlab',
  }

  file { "${software_list_generator_prefix}/upload_software_list.py":
    owner   => 'root',
    mode    => '0700',
    content => epp('dnf2git/upload_software_list.py', {
      'token'      => $gitlab_token,
      'repository' => $gitlab_repository,
      'path'       => $subdirectory,
      'gitlab_url' => $gitlab_url,
      'prefix'     => $software_list_generator_prefix,
      'hostname'   => "${facts['networking']['hostname']}${domain}",
      'branch'     => $branch,
    }),
     require => Uv::Venv['software_list_generator_env']
  }

  # Ensure the DNF post-transaction actions plugin is installed
  package { 'python3-dnf-plugin-post-transaction-actions':
    ensure => installed,
  }

  # Ensure the configuration directory exists with correct permissions
  file { '/etc/dnf/plugins/post-transaction-actions.d':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => Package['python3-dnf-plugin-post-transaction-actions'],
  }

  # Create the custom action configuration file
  file { '/etc/dnf/plugins/post-transaction-actions.d/custom-action.action':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "# Managed by Puppet\n*:any:${software_list_generator_prefix}/upload_software_list.py\n",
    require => [File['/etc/dnf/plugins/post-transaction-actions.d'], File["${software_list_generator_prefix}/upload_software_list.py"]],
  }
}

