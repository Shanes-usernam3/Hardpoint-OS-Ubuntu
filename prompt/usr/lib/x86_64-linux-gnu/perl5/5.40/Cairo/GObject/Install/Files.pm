package Cairo::GObject::Install::Files;

$self = {
          'deps' => [
                      'Cairo',
                      'Glib'
                    ],
          'inc' => '-I/usr/include/cairo -I/usr/include/libpng16 -I/usr/include/freetype2 -I/usr/include/pixman-1 -I/usr/include/glib-2.0 -I/usr/lib/x86_64-linux-gnu/glib-2.0/include -I/usr/include/sysprof-6 -pthread ',
          'libs' => '-lcairo-gobject -lcairo -lgobject-2.0 -lglib-2.0 ',
          'typemaps' => []
        };

@deps = @{ $self->{deps} };
@typemaps = @{ $self->{typemaps} };
$libs = $self->{libs};
$inc = $self->{inc};

	$CORE = undef;
	foreach (@INC) {
		if ( -f $_ . "/Cairo/GObject/Install/Files.pm") {
			$CORE = $_ . "/Cairo/GObject/Install/";
			last;
		}
	}

	sub deps { @{ $self->{deps} }; }

	sub Inline {
		my ($class, $lang) = @_;
		+{ map { (uc($_) => $self->{$_}) } qw(inc libs typemaps) };
	}

1;
