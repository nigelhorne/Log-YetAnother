package Log::YetAnother;

use strict;
use warnings;
use Carp;  # Import Carp for warnings
use Params::Get;  # Import Params::Get for parameter handling
use Sys::Syslog;  # Import Sys::Syslog for syslog support
use Scalar::Util 'blessed';  # Import Scalar::Util for object reference checking

=head1 NAME

Log::YetAnother - A flexible logging class for Perl

=head1 VERSION

0.01

=cut

our $VERSION = 0.01;

=head1 SYNOPSIS

  use Log::YetAnother;

  my $logger = Log::YetAnother->new(logger => 'logfile.log');

  $logger->debug('This is a debug message');
  $logger->info('This is an info message');
  $logger->notice('This is a notice message');
  $logger->trace('This is a trace message');
  $logger->warn({ warning => 'This is a warning message' });

=head1 DESCRIPTION

The C<Log::YetAnother> class provides a flexible logging mechanism that can handle different types of loggers,
including code references, arrays, file paths, and objects. It also supports logging to syslog if configured.

=head1 METHODS

=head2 new

  my $logger = Log::YetAnother->new(%args);

Creates a new C<Log::YetAnother> object. The following arguments can be provided:

=over

=item * C<logger> - A logger can be a code reference, an array reference, a file path, or an object.

=item * C<syslog> - A hash reference for syslog configuration.

=back

=cut

sub new {
	my ($class, %args) = @_;
	my $self = {
		messages => [],  # Initialize messages array
		%args,
	};
	return bless $self, $class;  # Bless and return the object
}

=head2 _log

  $logger->_log($level, @messages);

Internal method to log messages. This method is called by other logging methods.

=cut

sub _log {
	my ($self, $level, @messages) = @_;

	if(!UNIVERSAL::isa((caller)[0], __PACKAGE__)) {
		Carp::croak('Illegal Operation: This method can only be called by a subclass');
	}

	# Push the message to the internal messages array
	push @{$self->{messages}}, { level => $level, message => join(' ', grep defined, @messages) };

	if (my $logger = $self->{logger}) {
		if (ref($logger) eq 'CODE') {
			# If logger is a code reference, call it with log details
			$logger->({
				class => blessed($self) || __PACKAGE__,
				file => (caller(1))[1],
		# function => (caller(1))[3],
				line => (caller(1))[2],
				level => $level,
				message => \@messages,
			});
		} elsif (ref($logger) eq 'ARRAY') {
			# If logger is an array reference, push the log message to the array
			push @{$logger}, { level => $level, message => join(' ', grep defined, @messages) };
		} elsif (!ref($logger)) {
			# If logger is a file path, append the log message to the file
			if (open(my $fout, '>>', $logger)) {
				print $fout uc($level), ': ', blessed($self) || __PACKAGE__, ' ', (caller(1))[1], (caller(1))[2], ' ', join(' ', @messages), "\n";
				close $fout;
			}
		} else {
			# If logger is an object, call the appropriate method on the object
			$logger->$level(@messages);
		}
	}
}

=head2 debug

  $logger->debug(@messages);

Logs a debug message.

=cut

sub debug {
	my $self = shift;
	$self->_log('debug', @_);
}

=head2 info

  $logger->info(@messages);

Logs an info message.

=cut

sub info {
	my $self = shift;
	$self->_log('info', @_);
}

=head2 notice

  $logger->notice(@messages);

Logs a notice message.

=cut

sub notice {
	my $self = shift;
	$self->_log('notice', @_);
}

=head2 trace

  $logger->trace(@messages);

Logs a trace message.

=cut

sub trace {
	my $self = shift;
	$self->_log('trace', @_);
}

=head2 warn

  $logger->warn(@messages);

Logs a warning message. This method also supports logging to syslog if configured.

=cut

sub warn {
	my $self = shift;
	my $params = Params::Get::get_params('warning', @_);  # Get parameters

	# Validate input parameters
	return unless ($params && (ref($params) eq 'HASH'));
	my $warning = $params->{warning};
	return unless ($warning);

	if ($self eq __PACKAGE__) {
		# If called from a class method, use Carp to warn
		Carp::carp($warning);
		return;
	}

	if ($self->{syslog}) {
		# Handle syslog-based logging
		if (ref($self->{syslog}) eq 'HASH') {
			Sys::Syslog::setlogsock($self->{syslog});
		}
		openlog($self->{script_name}, 'cons,pid', 'user');
		syslog('warning|local0', $warning);
		closelog();
	}

	# Log the warning message
	$self->_log('warn', $warning);
	if ((!defined($self->{logger})) && (!defined($self->{syslog}))) {
		# Fallback to Carp if no logger or syslog is defined
		Carp::carp($warning);
	}
}

=head1 AUTHOR

Nigel Horne <njh@nigelhorne.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025 Nigel Horne

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;  # End of Log::YetAnother package
