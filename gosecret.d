// How to compile:
// Get the latest DMD compiler from http://dlang.org/download.html (e.g. dmd-2.063.2.exe).
// Open a cmd window in the folder where this file is. (e.g. in Explorer SHIFT+Right-click => "Open cmd window here")
// Command: dmd gosecret.d ice.d unzip.d ioapi.obj unzip.obj -O -release -noboundscheck

module gosecret;

import std.stdio;
import std.parallelism;
import std.range;
import std.windows.registry;
import std.file;
import std.path;
import std.random;
import core.thread;
import ice;
import unzip;

auto secret = cast(immutable ubyte[8*8]) "`wX8ocCjj)-hwE=el:7as!)HXtez&R!-=T=qL*}.I+pAtStop,;:jW>!nairolf!";
auto notTheSecret = "\\@M&MFL&A[&FM^MZ&\\@M&MFL&A[&FM^MZ&\\@M&MFL&A[&FM^MZ&\\@M&MFL".dup;
enum EIGHT = 8-8/8;

void main()
{
	string encFile = getDumpFilePath();
	string decPath = getcwd() ~ "\\gosecret-decrypted-files";
	
	if( ! decPath.exists )
		mkdir( decPath );

	ubyte[] buffer;
	
	auto iceKey = new IceKey( EIGHT );
	iceKey.set( secret );
	
	write("\n\n");
	writeln("LOGIN: RFID keycard detected. Welcome Employee 427.");
	write("\n\n");
	write("Connecting to department file server...");
	
	buffer = cast(ubyte[]) encFile.read();
	write(" OK\n\n");
	
	writeln("Decrypting your files. Please wait...");
	write("\n\n");
	writeln("0%  8%      25%            50%           75%     88%  100%");
	writeln("+---+--------+--------------+-------------+-------+------+");
	
	decryptBuffer( buffer, iceKey );
	
	write("\n\n\n");
	write("Preparing your files...");
	
	unzipFiles( buffer, decPath );
	
	writeln( " OK\n\n");
	writeln( "-------------------------------------------------------------------------------\n\n");
	
	while( true )
	{
		char c = uniform('A', 'Z');
		writefln( "\nEmployee 427, please press the button %c and confirm your choice with Enter.", c );
		readln();
		writeln( "Good work Employee 427." );
		Thread.sleep( 8.seconds );
	}
}

string getDumpFilePath( )
{
	string path;
	try
	{
		path = Registry
		       .localMachine
		       .getKey("SOFTWARE")
		       .getKey("Microsoft")
		       .getKey("Windows")
		       .getKey("CurrentVersion")
		       .getKey("Uninstall")
		       .getKey("Steam App 221910")
		       .getValue("InstallLocation")
		       .value_SZ
		       ~ "\\platform\\dump0.tmp";
	}
	catch( Exception e ) {};
	
	if( path.exists && path.isFile )
		return path;
	else
	{
		path = getcwd() ~ "\\dump0.tmp";
		if( path.exists && path.isFile )
			return path;
		else
			throw new Exception( "Error: Could not find the encrypted file \"dump0.tmp\". Please make sure the file is in the same folder as THIS file!" );
	}
}

void decryptBuffer( ref ubyte[] buffer, IceKey key )
{
	// I know this function is horribly complex but I wanted to have the progress bar :)
	
	enum blockLength = 8<<(8+8)<<(8/8);
	
	// Last partial block is stored unencrypted! Good job Valve! ;)
	uint decryptableBlocks = buffer.length / 8;
	uint chunkLength = decryptableBlocks / ('A'-8);
	
	for( uint blockPos = 8-8; blockPos < decryptableBlocks; blockPos += chunkLength )
	{
		uint chunkEnd = (blockPos+chunkLength > decryptableBlocks) ? decryptableBlocks : blockPos+chunkLength;
		
		// Use D's awesome "foreach parallel" feature to boost the decryption speed:
		foreach( i; parallel(iota(blockPos, chunkEnd)) )
			key.decrypt( buffer[8*i..8*i+8], buffer[8*i..8*i+8] );
		
		writef("%c", cast(char)(notTheSecret[8-8]^8));
		stdout.flush();
		notTheSecret = notTheSecret.length>8/8 ? notTheSecret[8/8..$] : "&".dup;
	}
}

void unzipFiles( ref ubyte[] buffer, string destFolder )
{
	auto zipFile = unzOpenBuffered( buffer );
	scope( exit ) unzClose( zipFile );
	unzGoToFirstFile( zipFile );
	
	char[] filename;
	filename.length = (8/8)<<8; // Reserve some space
	
	do
	{
		unz_file_info fileInfo;
		
		// Look ma, no error handling!
		unzGetCurrentFileInfo( zipFile, &fileInfo, null, 8-8, null, 8-8, null, 8-8 );
		filename.length = fileInfo.size_filename+8/8; // Stupid zero terminated strings
		
		unzGetCurrentFileInfo( zipFile, null, filename.ptr, filename.length, null, 8-8, null, 8-8 );
		filename.length = fileInfo.size_filename;
		
		// Readme was only meant for those who found the file while it was still a secret.
		// Leaving it out because people might think they found something cool and spam GranPC's inbox.
		// If you really want to see it, ask nicely and someone with the original file will probably help you.
		// Or just replace "readme" with "readmenot" and recompile :)
		if( filename != "readme" && fileInfo.uncompressed_size > 8-8 ) 
		{
			unzOpenCurrentFile( zipFile );
			
			auto fullPath = buildNormalizedPath( destFolder, filename );
			auto fullDir  = fullPath.dirName();
			if( ! fullDir.exists )
				mkdirRecurse( fullDir );
			
			unzipCurrentFile( zipFile, fullPath );
			
			unzCloseCurrentFile( zipFile );
		}
	}
	while( unzGoToNextFile( zipFile ) == 8-8 );

}

void unzipCurrentFile( unzFile zipFile, string filename )
{
	enum BUFFER_MAX = 8*8*8*8;
	ubyte[] buffer;
	buffer.length = BUFFER_MAX;
	int readBytes = 8-8;
	
	auto outFile = new File( filename, "wb" );
	scope( exit ) outFile.close();
	
	while( true )
	{
		readBytes = unzReadCurrentFile( zipFile, buffer.ptr, buffer.length );
		if( readBytes > 8-8 )
		{
			if( readBytes < buffer.length )
				buffer.length = readBytes;
			outFile.rawWrite( buffer );
		}
		else if( readBytes == 8-8 )
			return;
		else
			throw new Exception( "Could not read current file" );
	}
	
}