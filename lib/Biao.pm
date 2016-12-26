package Biao;
use Dancer ':syntax';
use Text::Trim;
use YAML;
use ZebraPrinter;

our $VERSION = '0.1';

get '/' => sub {
    my $file = 'items.yaml';
    my $items = [];
    $items = YAML::LoadFile( $file ) if -f $file;
    var items => $items;
    
    my $items_as_lines = join "\n", map { $_->{line} } @$items;
    var items_as_lines => $items_as_lines;

    template 'index', vars;
};

post '/items/save' => sub {
    my $raw = param 'items';
    my @lines = split /\n/, $raw;

    my @items;
    for ( @lines ){
        trim;
        next if $_ eq '';
        my ( $code, $name, $net, $storage ) = trim split /,/, $_;
        my $line = join ',', $code, $name, $net, $storage;
        push @items, { code => $code, name => $name, net => $net, storage => $storage, line => $line };
    }
    my @items_sorted = sort { $a->{code} <=> $b->{code} } @items;

    my $file = 'items.yaml';
    YAML::DumpFile( $file, \@items_sorted );

    to_json { ok => 1 };
};

post '/item/print' => sub {
    my $code = param 'code';
    my $qty = int param 'qty';

    my $file = 'items.yaml';
    my $items = [];
    $items = YAML::LoadFile( $file ) if -f $file;

    my ( $item ) = grep { $_->{code} eq $code } @$items;
    var item => $item;
    var qty => $qty;
    my $zpl = template 'item.zpl', vars, { layout => undef };

    #--------------------------------------------
    # 2仓3楼办公室
    # my $host = '192.168.11.237';
    my $host = '192.168.11.72';
    my $port = '9100';

    my $zebra = ZebraPrinter->new( host => $host, port => $port );
    unless ( $zebra->is_ready ) {
        my $errmsg = "打印机未就绪。";
        return to_json { ok => 0, errmsg => $errmsg };
    }

    # 开始打印
    $zebra->print_zpl($zpl);



    to_json { ok => 1, errmsg => Dump $item };
};


true;
