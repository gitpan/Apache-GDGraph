use ExtUtils::MakeMaker;

WriteMakefile(
	NAME		=> 'Apache::GD::Graph',
	VERSION_FROM	=> 'lib/Apache/GD/Graph.pm', # finds $VERSION
	ABSTRACT	=> 'Apache handler to generate graphs.',
	PREREQ_PM	=> {GD::Graph => 0, GD::Text::Align => 0},
	DISTNAME	=> 'Apache-GDGraph',
	dist		=> {
		COMPRESS => 'gzip -9f',
		SUFFIX   => 'gz',
	}
);
