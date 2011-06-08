{
    name              => 'TestAppContainer',
    view              => 'View::TT',
    'Controller::Foo' => { foo => 'bar' },
    'Model::Baz'      => { qux => 'xyzzy' },
    foo_sub           => '__foo(x,y)__',
    literal_macro     => '__literal(__DATA__)__',
    environment_macro => '__ENV(CATALYST_HOME)__/mockapp.pl',
    Plugin            => { Zot => { zoot => 'zooot' } },
}
