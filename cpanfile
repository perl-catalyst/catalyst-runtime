# install these with the command:
# cpanm --installdeps --with-develop .
on 'develop' => sub {
    requires 'Test::Simple' => '0.88';
    requires 'Test::Aggregate' => '0.364';
    requires 'CatalystX::LeakChecker' => '0.05';
    requires 'Catalyst::Devel' => '1.0';        # For http server test
    requires 'Test::WWW::Mechanize::Catalyst' => '0.51';
    requires 'Test::TCP' => '1.27';             # ditto, ships Net::EmptyPort
    requires 'File::Copy::Recursive' => 0;
    requires 'Catalyst::Engine::PSGI' => 0;
    requires 'Test::Without::Module' => 0;
    requires 'Starman' => 0;
    requires 'MooseX::Daemonize' => 0;
    requires 'Test::NoTabs' => 0;
    requires 'Test::Pod' => 0;
    requires 'Test::Pod::Coverage' => 0;
    requires 'Test::Spelling' => 0;
    requires 'Pod::Coverage::TrustPod' => 0;
    requires 'Catalyst::Plugin::Params::Nested' => 0;
    requires 'Catalyst::Plugin::ConfigLoader' => 0;
};
