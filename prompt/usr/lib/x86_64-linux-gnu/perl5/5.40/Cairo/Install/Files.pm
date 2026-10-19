package Cairo::Install::Files;

$self = {
          'deps' => [],
          'inc' => '-I. -Ibuild -I/usr/include/cairo -I/usr/include/libpng16 -I/usr/include/freetype2 -I/usr/include/pixman-1  -I/usr/include/cairo -I/usr/include/libpng16 -I/usr/include/freetype2 -I/usr/include/pixman-1 ',
          'libs' => '-lcairo  -lcairo -lfreetype ',
          'typemaps' => [
                          'cairo-perl-auto.typemap',
                          'cairo-perl.typemap'
                        ]
        };

@deps = @{ $self->{deps} };
@typemaps = @{ $self->{typemaps} };
$libs = $self->{libs};
$inc = $self->{inc};

	$CORE = undef;
	foreach (@INC) {
		if ( -f $_ . "/Cairo/Install/Files.pm") {
			$CORE = $_ . "/Cairo/Install/";
			last;
		}
	}

	sub deps { @{ $self->{deps} }; }

	sub Inline {
		my ($class, $lang) = @_;
		+{ map { (uc($_) => $self->{$_}) } qw(inc libs typemaps) };
	}

1;
