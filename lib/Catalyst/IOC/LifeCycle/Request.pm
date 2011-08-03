package Catalyst::IOC::LifeCycle::Request;
use Moose::Role;
use namespace::autoclean;

# based on Bread::Board::LifeCycle::Request from OX
# just behaves like a singleton - ::Request instances
# will get flushed after the response is sent
with 'Bread::Board::LifeCycle::Singleton';

1;
