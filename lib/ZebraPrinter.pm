package ZebraPrinter;
use strict;
use utf8;

use Class::Date qw/date now/;
use FindBin;
use IO::Socket::IP;
use IO::Socket::Timeout;
use Moo;
use Template;
use Text::Trim;
use XML::Simple;

has host => ( is => 'rw', default => sub {undef} );
has port => ( is => 'rw', default => sub {'9100'} );
has sock     => ( is => 'ro', lazy => 1, builder => '_build_sock' );
has template => ( is => 'rw', lazy => 1, builder => '_build_template' );

sub _build_sock {
    my $self = shift;
    die "set the printer host first please, dude.\n"                                             unless defined $self->host;
    die "set the printer port first please, dude. default is 9100 if within the same network.\n" unless defined $self->port;

    my $sock = IO::Socket::IP->new(
        PeerHost => $self->host,
        PeerPort => $self->port,
        Type     => SOCK_STREAM,
        Timeout => 5,
    );
    return $sock;
}

sub _build_template {
    my $self = shift;
    my ($include_path) = grep {-d} ( "$FindBin::Bin/../views", "$FindBin::Bin/../templates", "$FindBin::Bin/templates", "$FindBin::Bin" );
    my $template = Template->new(
        {   INCLUDE_PATH => $include_path,
            ANYCASE      => 1,
            ABSOLUTE     => 1,
            ENCODING     => 'utf8',
        }
    );
    return $template;
}

#--------------------------
# object methods

sub is_ready { shift->sock ? 1 : 0 }

sub print {
    my $self = shift;
    my $zpl  = $self->zpl(@_);
    $self->print_zpl($zpl);
}

sub zpl {
    my $self  = shift;
    my $given = shift || '';
    my $vars  = shift || {};

    $vars = $self->_inject_default_vars($vars);

    my $tt  = $self->template;
    my $zpl = '';

    # well, zpl language using '^' as default cmd prefix character
    # treat the given as raw zpl template string
    if ( $given =~ /\^/ ) {
        $tt->process( \$given, $vars, \$zpl ) || die $tt->error;
    }

    # otherwise, the given should be the template file path
    else {
        my $filename = sprintf "%s.tt", $given;
        $tt->process( $filename, $vars, \$zpl ) || die $tt->error;
    }

    return $zpl;
}

sub print_zpl {
    my $self = shift;
    my $zpl  = shift;
    binmode $self->sock, ':utf8';
    $self->sock->print($zpl);
}

sub _inject_default_vars {
    my $self = shift;
    my $vars = shift || {};

    my $today = now->truncate;
    $vars->{today} = $today;
    $vars->{ymd} = $today->strftime('%Y%m%d');
    $vars->{ymd} =~ s/^20//;

    return $vars;
}

sub _ask {
    my $self = shift;
    my $zpl = shift;
    my $sock = $self->sock;

    IO::Socket::Timeout->enable_timeouts_on($sock);
    $sock->read_timeout(1);
    binmode $sock, ':utf8';
    $sock->print($zpl);

    my @line = $sock->getlines;
    return \@line;
}

sub desc {
    my $self = shift;
    my $zpl = '^XA^HZa^XZ';
    my $lines = $self->_ask( $zpl );
    my $xml = join '', @$lines;

    my  $xs = XML::Simple->new( ContentKey => 'text' );
    my $ret = $xs->XMLin($xml);

    my $info = {};
    $info->{name} = $ret->{'SAVED-SETTINGS'}{'NAME'};
    $info->{ip} = $ret->{'INTERFACES'}{'NETWORK'}{'NETWORK-INTERFACE-SPECIFIC'}{'TCP'}{'IP-ADDRESS'}{'INTERNAL-WIRED'};
    # $info->{_raw} = $ret;
    return $info;
}

sub info {
    my $self = shift;
    my $zpl = '^XA~HI^XZ';
    my $lines = $self->_ask( $zpl );

    # 分解
    my $strings = join ',', grep { s/\r\n$//; s/^\x02//; s/\x03$//; } @$lines;
    my @keys = split /,/, 'modal,version,dpm,memory,x';
    my @values = trim split /,/, $strings;

    # 配对
    my $raw = {};
    for ( @keys ){
        $raw->{$_} = shift @values;
    }

    # 去掉无用的
    delete $raw->{x};

    return $raw;
}

# 查询打印机状态
sub status {
    my $self = shift;
    my $zpl = '^XA~HS^XZ';
    my $lines = $self->_ask( $zpl );
    
    # 一共三行，去头去尾，直接合并
    my $strings = join ',', grep { s/\r\n$//; s/^\x02//; s/\x03$//; } @$lines;
    my @keys = split /,/, 'aaa,b,c,dddd,eee,f,g,h,iii,j,k,l,mmm,n,o,p,q,r,s,t,uuuuuuuu,v,www,xxxx,y';
    my @values = split /,/, $strings;

    # 按照文档，合并数据项先
    my $raw = {};
    for ( @keys ){
        $raw->{$_} = shift @values;
    }

    # 再解析有意义的字段，重新定义返回数据
    my $status = {};
    $status->{paper_out} = $raw->{b};
    $status->{has_paused} = $raw->{c};
    $status->{jobs_in_buffer} = int $raw->{eee};
    $status->{buffer_full} = $raw->{f};
    $status->{label_length} = int $raw->{dddd};
    $status->{over_heat} = $raw->{l};
    $status->{files} = int $raw->{www};
    $status->{password} = $raw->{xxxx};

    return $status;
}

# 列出闪存上的字体和图片，用于统一管理
sub listing {
    my $self = shift;
    my $zpl = '^XA^HWE:*.*^XZ';
    my $lines = $self->_ask( $zpl );

    my @files;
    for ( @$lines ){
        my @parts = split /\s+/;
        if ( /^\*/ ){
            push @files, {
                name => $parts[1],
                size => $parts[2],
                ref => $parts[3],
            };

        }elsif ( /^-/ ){

        }
    }

    return \@files;
}

1;

