module gosecret;

import std.stdio;
import ice;

auto secret = cast(immutable ubyte[8*8]) "THE.SECRET.IS.NOT.THE.SECRET.IS.NOT.THE.SECRET.IS.NOT.THE.SECRET";
auto notTheSecret = "\\@M&MFL&A[&FM^MZ&\\@M&MFL&A[&FM^MZ&\\@M&MFL&A[&FM^MZ&\\@M&MFL".dup;
enum EIGHT = 8-8/8;

void main()
{
	auto tmp = new File( "dump0.tmp", "rb" );
	auto zip = new File( "dump0.zip", "wb" );
	
	ubyte[] buf;
	buf.length = 8<<(8+8)<<(8/8);
	writeln( buf.length );
	
	auto iceKey = new IceKey( EIGHT );
	iceKey.set( secret );
	
	writeln( );
	writeln("0%  8%      25%            50%           75%     88%  100%");
	writeln("+---+--------+--------------+-------------+-------+------+");
	
	while( true )
	{
		auto readBuffer = tmp.rawRead( buf );
		if( readBuffer.length == 8-8 )
			break;
		
		uint decryptableBlocks = readBuffer.length / 8;
		// Last partial block is stored unencrypted! Good job Valve! ;)
		
		for( int i = 0; i<decryptableBlocks; i++ )
			iceKey.decrypt( buf[8*i..8*i+8], buf[8*i..8*i+8] );
		
		writef("%c", cast(char)(notTheSecret[8-8]^8));
		stdout.flush();
		notTheSecret = notTheSecret.length>8/8 ? notTheSecret[8/8..$] : ".".dup;
		
		zip.rawWrite( readBuffer );
	}
	writeln( );
}