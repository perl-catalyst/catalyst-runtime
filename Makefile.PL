use strict;
use warnings;
use 5.008003;

my %META = (
  name => 'Catalyst-Runtime',
  license => 'perl_5',
  prereqs => {
    configure => { requires => {
      'ExtUtils::MakeMaker'   => 0,
    } },
    build => { requires => {
    } },
    test => {
      requires => {
        'Test::Fatal' => 0,
        'Test::More' => '0.88',
        'HTTP::Request::Common' => 0,
        'HTTP::Status' => 0,
      },
    },
    runtime => {
      requires => {
        'perl'                  => 5.008003,
        'List::Util'            => '1.45',
        'namespace::clean'      => '0.23',
        'MooseX::Emulate::Class::Accessor::Fast' => '0.00903',
        'Class::Load'           => '0.12',
        'Moose'                 => '1.03',
        'MooseX::MethodAttributes::Role::AttrContainer::Inheritable' => '0.24',
        'MooseX::Role::WithOverloading' => '0.09',
        'Carp'                  => '1.25',
        'Class::C3::Adopt::NEXT' => '0.07',
        'CGI::Simple::Cookie'   => '1.109',
        'Data::Dump'            => 0,
        'Data::OptList'         => 0,
        'HTML::Entities'        => 0,
        'HTML::HeadParser'      => 0,
        'HTTP::Body'            => '1.22',
        'HTTP::Headers'         => '1.64',
        'HTTP::Request'         => '5.814',
        'HTTP::Response'        => '5.813',
        'Module::Pluggable'     => '4.7',
        'Path::Class'           => '0.09',
        'Scalar::Util'          => 0,
        'Sub::Exporter'         => 0,
        'Text::SimpleTable'     => '0.03',
        'Time::HiRes'           => 0,
        'Tree::Simple'          => '1.15',
        'Tree::Simple::Visitor::FindByUID' => 0,
        'Try::Tiny'             => '0.17',
        'Safe::Isa'             => 0,
        'Socket'                => '1.96',
        'Task::Weaken'          => 0,
        'Text::Balanced'        => 0, # core in 5.8.x but mentioned for completeness
        'MRO::Compat'           => 0,
        'MooseX::Getopt'        => '0.48',
        'String::RewritePrefix' => '0.004', # Catalyst::Utils::resolve_namespace
        'Devel::InnerPackage'   => 0, # No longer core in blead
        'Plack'                 => '0.9991', # IIS6+7 fix middleware
        'Plack::Middleware::ReverseProxy' => '0.04',
        'Plack::Test::ExternalServer' => 0,
        'Encode'                => '2.49',
        'LWP'                   => '5.837', # LWP had unicode fail in 5.8.26
        'URI'                   => '1.65',
        'URI::ws'               => '0.03',
        'JSON::MaybeXS'         => '1.000000',
        'Stream::Buffered'      => 0,
        'Hash::MultiValue'      => 0,
        'Plack::Request::Upload' => 0,
        'CGI::Struct'           => 0,
        "Plack::Middleware::Conditional" => 0,
        "Plack::Middleware::IIS6ScriptNameFix" => 0,
        "Plack::Middleware::IIS7KeepAliveFix" => 0,
        "Plack::Middleware::LighttpdScriptNameFix" => 0,
        "Plack::Middleware::ContentLength" => 0,
        "Plack::Middleware::Head" => 0,
        "Plack::Middleware::HTTPExceptions" => 0,
        "Plack::Middleware::FixMissingBodyInRedirect" => '0.09',
        "Plack::Middleware::MethodOverride" => '0.12',
        "Plack::Middleware::RemoveRedundantBody" => '0.03',
        'PerlIO::utf8_strict' => 0,
      },
    },
    develop   => {
      requires => {
        'Test::TCP'               => '2.00',
        'File::Copy::Recursive'   => '0.40',
        'Starman'                 => 0,
        'MooseX::Daemonize'       => 0,
        'Test::NoTabs'            => 0,
        'Test::Pod'               => 0,
        'Test::Pod::Coverage'     => 0,
        'Test::Spelling'          => 0,
        'Pod::Coverage::TrustPod' => 0,
        'Catalyst::Plugin::Params::Nested' => 0,
        'Compress::Zlib'          => 0,
        'Catalyst::Action::REST'  => 0,
        'Type::Tiny'              => 0,
        'Proc::ProcessTable'      => 0,
      },
    },
  },
  resources => {
    repository => {
      # r/w: catagits@git.shadowcat.co.uk:Catalyst-Runtime.git
      url => 'git://git.shadowcat.co.uk/catagits/Catalyst-Runtime.git',
      web => 'http://git.shadowcat.co.uk/gitweb/gitweb.cgi?p=catagits/Catalyst-Runtime.git;a=summary',
      type => 'git',
    },
    x_IRC => 'irc://irc.perl.org/#catalyst',
    bugtracker => {
      web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Catalyst-Runtime',
      mailto => 'bug-Catalyst-Runtime@rt.cpan.org',
    },
    license => [ 'http://dev.perl.org/licenses/' ],
    x_MailingList => 'http://lists.scsys.co.uk/cgi-bin/mailman/listinfo/catalyst',
    homepage => 'http://dev.catalyst.perl.org/',
  },
  no_index => {
    directory => [ 't', 'xt' ]
  },
  x_breaks => {
    'Catalyst::Plugin::SubRequest' => '<= 0.14',
    'Catalyst::Model::Akismet' => '<= 0.02',
    'Catalyst::Component::ACCEPT_CONTEXT' => '<= 0.06',
    'Catalyst::Plugin::ENV' => 0, # This plugin is just stupid, full stop
                                  # should have been a core fix.
    'Catalyst::Plugin::Unicode::Encoding' => '<= 0.2',
    'Catalyst::Plugin::Authentication' => '<= 0.10010', # _config accessor in ::Credential::Password
    'Catalyst::Authentication::Credential::HTTP' => '<= 1.009',
    'Catalyst::Plugin::Session::Store::File'     => '<= 0.16',
    'Catalyst::Plugin::Session'                  => '<= 0.21',
    'Catalyst::Plugin::Session::State::Cookie'   => '<= 0.10',
    'Catalyst::Plugin::Session::Store::FastMmap' => '<= 0.09',
    'Catalyst::Controller::AllowDisable'         => '<= 0.03',
    'Reaction'                                   => '<= 0.001999',
    'Catalyst::Plugin::Upload::Image::Magick'    => '<= 0.03',
    'Catalyst::Plugin::ConfigLoader'             => '<= 0.22', # Older versions work but
                                                  # throw Data::Visitor warns
    'Catalyst::Devel'                            => '<= 1.19',
    'Catalyst::Plugin::SmartURI'                 => '<= 0.032',
    'CatalystX::CRUD'                            => '<= 0.37',
    'Catalyst::Action::RenderView'               => '<= 0.07',
    'Catalyst::Plugin::DebugCookie'              => '<= 0.999002',
    'Catalyst::Plugin::Authentication'           => '<= 0.100091',
    'CatalystX::Imports'                         => '<= 0.03',
    'Catalyst::Plugin::HashedCookies'            => '<= 1.03',
    'Catalyst::Action::REST'                     => '<= 0.67',
    'CatalystX::CRUD'                            => '<= 0.42',
    'CatalystX::CRUD::Model::RDBO'               => '<= 0.20',
    'Catalyst::View::Mason'                      => '<= 0.17',
#    Note these are not actually needed - they fail tests against the
#    new version, but still work fine..
#    'Catalyst::ActionRole::ACL'                  => '<= 0.05',
#    'Catalyst::Plugin::Session::Store::DBIC'     => '<= 0.11',
    'Test::WWW::Mechanize::Catalyst'            => '<= 0.53', # Dep warnings unless upgraded.
  },
  x_authority => 'cpan:MSTROUT',
);

my $tests = 't/*.t t/aggregate/*.t';

my %MM_ARGS = (
  test => { TESTS => $tests },
  EXE_FILES => [ glob 'script/*.pl' ],
  PREREQ_PM => {
    (eval { require Moose; Moose->VERSION('2.1300') } ? () : (
      'MooseX::Role::WithOverloading' => '0.09'
    )),
  },
);

## BOILERPLATE ###############################################################
require ExtUtils::MakeMaker;
(do './maint/Makefile.PL.include' or die $@) unless -f 'META.yml';

# have to do this since old EUMM dev releases miss the eval $VERSION line
my $eumm_version  = eval $ExtUtils::MakeMaker::VERSION;
my $mymeta        = $eumm_version >= 6.57_02;
my $mymeta_broken = $mymeta && $eumm_version < 6.57_07;

($MM_ARGS{NAME} = $META{name}) =~ s/-/::/g;
($MM_ARGS{VERSION_FROM} = "lib/$MM_ARGS{NAME}.pm") =~ s{::}{/}g;
$META{license} = [ $META{license} ]
  if $META{license} && !ref $META{license};
$MM_ARGS{LICENSE} = $META{license}[0]
  if $META{license} && $eumm_version >= 6.30;
$MM_ARGS{NO_MYMETA} = 1
  if $mymeta_broken;
$MM_ARGS{META_ADD} = { 'meta-spec' => { version => 2 }, %META }
  unless -f 'META.yml';

for (qw(configure build test runtime)) {
  my $key = $_ eq 'runtime' ? 'PREREQ_PM' : uc $_.'_REQUIRES';
  my $r = $MM_ARGS{$key} = {
    %{$META{prereqs}{$_}{requires} || {}},
    %{delete $MM_ARGS{$key} || {}},
  };
  defined $r->{$_} or delete $r->{$_} for keys %$r;
}

$MM_ARGS{MIN_PERL_VERSION} = delete $MM_ARGS{PREREQ_PM}{perl} || 0;

delete $MM_ARGS{MIN_PERL_VERSION}
  if $eumm_version < 6.47_01;
$MM_ARGS{BUILD_REQUIRES} = {%{$MM_ARGS{BUILD_REQUIRES}}, %{delete $MM_ARGS{TEST_REQUIRES}}}
  if $eumm_version < 6.63_03;
$MM_ARGS{PREREQ_PM} = {%{$MM_ARGS{PREREQ_PM}}, %{delete $MM_ARGS{BUILD_REQUIRES}}}
  if $eumm_version < 6.55_01;
delete $MM_ARGS{CONFIGURE_REQUIRES}
  if $eumm_version < 6.51_03;

ExtUtils::MakeMaker::WriteMakefile(%MM_ARGS);
## END BOILERPLATE ###########################################################

print <<"EOF";

 Important:

    This library is for running Catalyst applications.

    For development and use of catalyst.pl and myapp_create.pl, make sure
    you also install the development tools package Catalyst::Devel.

        perl -MCPAN -e 'install Catalyst::Devel'     # or
        cpanm Catalyst::Devel

    To get some commonly used plugins, as well as the TT view and DBIC
    model, install Task::Catalyst in the same way.

 Have fun!
EOF
