=head1 NAME

Catalyst::Manual - User guide and reference for Catalyst

=head1 DESCRIPTION

This is the (table of contents page of the) comprehensive user guide and
reference for Catalyst.

=head1 IMPORTANT NOTE

If you need to read the Catalyst Manual make sure that you have
Catalyst::Manual installed from cpan.  To check that it is installed
run the following command from a unix (bash) prompt:

 $ perldoc -t Catalyst::Manual::Tutorial::CatalystBasics 2>&1 >/dev/null && echo OK || echo MISSING

If you see "OK" as the output, it's there, if you see "MISSING" you
need to install the L<Catalyst::Manual> distribution
(L<http://search.cpan.org/dist/Catalyst-Manual/>).

=over 4

=item *

L<Catalyst::Manual::About>

Explanation (without code) of what Catalyst is and why to use it.

=item *

L<Catalyst::Manual::Intro>

Introduction to Catalyst. This is a detailed, if unsystematic, look at 
the basic concepts of Catalyst and what the best practices are for 
writing applications with it.

=item *

L<Catalyst::Manual::Tutorial>

A detailed step-by-step tutorial going through a single application
thoroughly.

=item *

L<Catalyst::Manual::Plugins>

Catalyst Plugins and Components. A brief look at some of the very many
modules for extending Catalyst.

=item *

L<Catalyst::Manual::Cookbook>

Cooking with Catalyst. Recipes and solutions that you might want to use
in your code.

=item *

L<Catalyst::Manual::Installation>

How to install Catalyst, in a variety of different ways. A closer look
at one of the more difficult issues of using the framework--getting it.

=item *

L<Catalyst::Manual::WritingPlugins>

Writing plugins for Catalyst; the use of L<NEXT>.

=item *

L<Catalyst::Manual::Internals>

Here be dragons! A very brief explanation of the Catalyst request cycle,
the major components of Catalyst, and how you can use this knowledge
when writing applications under Catalyst.

=back

=head1 SUPPORT

IRC:

    Join #catalyst on irc.perl.org.

Mailing-Lists:

    http://lists.rawmode.org/mailman/listinfo/catalyst
    http://lists.rawmode.org/mailman/listinfo/catalyst-dev

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
