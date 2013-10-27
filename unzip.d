module unzip;

import std.c.string;

// Very VERY crude binding to some of the minizip functions.
// Will be improved. I promise! :)

extern(C)
{
	unzFile unzOpen( const char* path );
	int     unzClose( unzFile file );
	
	unzFile unzOpen2( const char* path, zlib_filefunc_def* pzlib_filefunc_def );
	
	int     unzGoToFirstFile( unzFile file );
	int     unzGoToNextFile( unzFile file );
	
	int     unzGetCurrentFileInfo( unzFile file, unz_file_info* pfile_info,
                                   char* szFileName, uint fileNameBufferSize,
                                   void* extraField, uint extraFieldBufferSize,
                                   char* szComment,  uint commentBufferSize );
	
	int     unzOpenCurrentFile( unzFile file );
	int     unzOpenCurrentFilePassword( unzFile file, const char* password );
	int     unzCloseCurrentFile( unzFile file );
	
	int     unzReadCurrentFile( unzFile file, void* buf, uint len );
}

// Very bad idea, I know! Only ONE zip file can be open at any time!
zlib_filefunc_def fileFuncs;
ubyte[] streamBuf;
uint streamPos = 0;

unzFile unzOpenBuffered( ref ubyte[] fileBuffer )
{
	streamBuf = fileBuffer;
	fileFuncs.opaque = streamBuf.ptr;
	
	fileFuncs.zopen_file = &bufOpen;
	fileFuncs.zread_file = &bufRead;
	fileFuncs.zwrite_file = &bufWrite;
	fileFuncs.ztell_file =  &bufTell;
	fileFuncs.zseek_file = &bufSeek;
	fileFuncs.zclose_file = &bufClose;
	fileFuncs.zerror_file = &bufError;
	return unzOpen2( null, &fileFuncs );
}

enum ZLIB_FILEFUNC_SEEK_SET = 0;
enum ZLIB_FILEFUNC_SEEK_CUR = 1;
enum ZLIB_FILEFUNC_SEEK_END = 2;

extern(C)
{

	void* bufOpen( void* opaque, const char* filename, int mode )
	{
		streamPos = 0;
		return &streamPos;
	}

	uint bufRead( void* opaque, void* stream, void* buf, uint size )
	{
		uint readable = (streamBuf.length > streamPos) ? streamBuf.length-streamPos : 0;
		if( !readable ) return 0;
		readable = (size > readable) ? readable : size;
		memcpy(buf, &streamBuf[streamPos], readable);
		streamPos += readable;
		return readable;
	}
	
	uint bufWrite( void* opaque, void* stream, void* buf, uint size )
	{
		return 0;
	}
	
	int bufTell( void* opaque, void* stream )
	{
		return streamPos;
	}
	
	int bufSeek( void* opaque, void* stream, uint offset, int origin )
	{
		switch( origin )
		{
			case ZLIB_FILEFUNC_SEEK_SET:
				streamPos = offset;
				break;
			case ZLIB_FILEFUNC_SEEK_CUR:
				streamPos += offset;
				break;
			case ZLIB_FILEFUNC_SEEK_END:
				streamPos = streamBuf.length + offset;
				break;
			default:
				return -1;
		}
		return 0;
	}
	
	int bufClose( void* opaque, void* stream )
	{
		streamBuf = null;
		return 0;
	}
	
	int bufError( void* opaque, void* stream )
	{
		return 0;
	}
	

	struct unz_file_info
	{
		uint version_;
		uint version_needed;
		uint flag;
		uint compression_method;
		uint dosDate;
		uint crc;
		uint compressed_size;
		uint uncompressed_size;
		uint size_filename;
		uint size_file_extra;
		uint size_file_comment;
		uint disk_num_start;
		uint internal_fa;
		uint external_fa;
		tm_unz tmu_date;
	}

	struct tm_unz
	{
		uint tm_sec;
		uint tm_min;
		uint tm_hour;
		uint tm_mday;
		uint tm_mon;
		uint tm_year;
	}

	alias uint unzFile;

	struct zlib_filefunc_def
	{
		void* function( void* opaque, const char* filename, int mode ) zopen_file;
		uint function( void* opaque, void* stream, void* buf, uint size ) zread_file;
		uint function( void* opaque, void* stream, void* buf, uint size ) zwrite_file;
		int function( void* opaque, void* stream ) ztell_file;
		int function( void* opaque, void* stream, uint offset, int origin ) zseek_file;
		int function( void* opaque, void* stream ) zclose_file;
		int function( void* opaque, void* stream ) zerror_file;
		void* opaque;
	}
}