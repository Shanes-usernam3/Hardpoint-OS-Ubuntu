package Glib::Object::Introspection::Install::Files;

$self = {
          'deps' => [
                      'Glib'
                    ],
          'inc' => '-I/usr/include/gobject-introspection-1.0 -I/usr/include/glib-2.0 -I/usr/lib/x86_64-linux-gnu/glib-2.0/include -I/usr/include/sysprof-6 -pthread  -I/usr/include/glib-2.0 -I/usr/lib/x86_64-linux-gnu/glib-2.0/include -I/usr/include/sysprof-6 -pthread  ',
          'libs' => '-lgirepository-1.0 -lgobject-2.0 -lglib-2.0  -Wl,--export-dynamic -lgmodule-2.0 -pthread -lglib-2.0 -lglib-2.0  -lffi ',
          'typemaps' => []
        };

@deps = @{ $self->{deps} };
@typemaps = @{ $self->{typemaps} };
$libs = $self->{libs};
$inc = $self->{inc};

	$CORE = undef;
	foreach (@INC) {
		if ( -f $_ . "/Glib/Object/Introspection/Install/Files.pm") {
			$CORE = $_ . "/Glib/Object/Introspection/Install/";
			last;
		}
	}

	sub deps { @{ $self->{deps} }; }

	sub Inline {
		my ($class, $lang) = @_;
		+{ map { (uc($_) => $self->{$_}) } qw(inc libs typemaps) };
	}

1;
