{
    name                 => 'TestAppContainer',
    'Controller::Config' => { foo => 'foo' },
    cache                => '__HOME__/cache',
    multi                => '__HOME__,__path_to(x)__,__HOME__,__path_to(y)__',
}
