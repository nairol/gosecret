/*
 * D implementation of the ICE encryption algorithm.
 *
 * Ported from the C++ version by Matthew Kwan - July 1996
 */

module ice;

	/* Structure of a single round subkey */
struct IceSubkey
{
	uint val[3];
}


	/* The S-boxes */
immutable uint[1024][4] ice_sbox;

static this()
{
	// Initialise S-boxes
	for( int i=0; i<1024; i++ )
	{
		int col = (i >> 1) & 0xff;
		int row = (i & 0x1) | ((i & 0x200) >> 8);
		uint x;
		
		x = gf_exp7( col ^ ice_sxor[0][row], ice_smod[0][row] ) << 24;
		ice_sbox[0][i] = ice_perm32( x );
		
		x = gf_exp7( col ^ ice_sxor[1][row], ice_smod[1][row] ) << 16;
		ice_sbox[1][i] = ice_perm32( x );
		
		x = gf_exp7( col ^ ice_sxor[2][row], ice_smod[2][row] ) << 8;
		ice_sbox[2][i] = ice_perm32( x );
		
		x = gf_exp7( col ^ ice_sxor[3][row], ice_smod[3][row] );
		ice_sbox[3][i] = ice_perm32( x );
	}
}


	/* Modulo values for the S-boxes */
immutable int[4][4]	ice_smod =
	[[333, 313, 505, 369],
	 [379, 375, 319, 391],
	 [361, 445, 451, 397],
	 [397, 425, 395, 505]];

	/* XOR values for the S-boxes */
immutable int[4][4] ice_sxor =
	[[0x83, 0x85, 0x9B, 0xCD],
	 [0xCC, 0xA7, 0xAD, 0x41],
	 [0x4B, 0x2E, 0xD4, 0x33],
	 [0xEA, 0xCB, 0x2E, 0x04]];

	/* Permutation values for the P-box */
immutable uint[32] ice_pbox =
	[0x00000001, 0x00000080, 0x00000400, 0x00002000,
	 0x00080000, 0x00200000, 0x01000000, 0x40000000,
	 0x00000008, 0x00000020, 0x00000100, 0x00004000,
	 0x00010000, 0x00800000, 0x04000000, 0x20000000,
	 0x00000004, 0x00000010, 0x00000200, 0x00008000,
	 0x00020000, 0x00400000, 0x08000000, 0x10000000,
	 0x00000002, 0x00000040, 0x00000800, 0x00001000,
	 0x00040000, 0x00100000, 0x02000000, 0x80000000];

	/* The key rotation schedule */
immutable int[16] ice_keyrot =
	[0, 1, 2, 3, 2, 1, 3, 0,
	 1, 3, 2, 0, 3, 1, 0, 2];


/*
 * 8-bit Galois Field multiplication of a by b, modulo m.
 * Just like arithmetic multiplication, except that additions and
 * subtractions are replaced by XOR.
 */

uint gf_mult( uint a, uint b, uint m )
{
	uint res = 0;
	
	while( b )
	{
		if (b & 1)
			res ^= a;
		
		a <<= 1;
		b >>= 1;
		
		if (a >= 256)
			a ^= m;
	}
	
	return res;
}


/*
 * Galois Field exponentiation.
 * Raise the base to the power of 7, modulo m.
 */

uint gf_exp7( uint b, uint m )
{
	uint x;
	
	if( b == 0 )
		return 0;
	
	x = gf_mult (b, b, m);
	x = gf_mult (b, x, m);
	x = gf_mult (x, x, m);
	return gf_mult (b, x, m);
}


/*
 * Carry out the ICE 32-bit P-box permutation.
 */

uint ice_perm32( uint x )
{
	uint res = 0;
	auto i = 0;
	
	while( x )
	{
		if( x & 1 )
			res |= ice_pbox[i];
		i++;
		x >>= 1;
	}

	return res;
}


/*
 * The single round ICE f function.
 */

uint ice_f( uint p, const IceSubkey sk )
{
	uint tl, tr; /* Expanded 40-bit values */
	uint al, ar; /* Salted expanded 40-bit values */
	
	/* Left half expansion */
	tl = ((p >> 16) & 0x3ff) | (((p >> 14) | (p << 18)) & 0xffc00);
	
	/* Right half expansion */
	tr = (p & 0x3ff) | ((p << 2) & 0xffc00);
	
	/* Perform the salt permutation */
	al = sk.val[2] & (tl ^ tr);
	ar = al ^ tr;
	al ^= tl;
	
	/* XOR with the subkey */
	al ^= sk.val[0];
	ar ^= sk.val[1];
	
	/* S-box lookup and permutation */
	return ice_sbox[0][al >> 10] | ice_sbox[1][al & 0x3ff] | ice_sbox[2][ar >> 10] | ice_sbox[3][ar & 0x3ff];
}


class IceKey
{
	/// Create a new ICE key of length n
	this( uint n )
	{
		if( n < 1 )
		{
			size = 1;
			keysched.length = 8;
		}
		else
		{
			size = n;
			keysched.length = n * 16;
		}
	}
	
	
	/// Destroy an ICE key
	~this( )
	{
		foreach( ref subkey; keysched )
			subkey.val[] = 0;
		
		size = 0;
		keysched.length = 0;
	}
	
	
	/// Set the key schedule of an ICE key
	void set( const ubyte[] key )
	{
		if( keysched.length == 8 )
		{
			ushort kb[4];
			
			for( int i=0; i<4; i++ )
				kb[3 - i] = (key[i*2] << 8) | key[i*2 + 1];
			
			scheduleBuild( kb, 0, ice_keyrot[0..8] );
			return;
		}
		
		for( int i=0; i<size; i++ )
		{
			ushort kb[4];
			
			for( int j=0; j<4; j++ )
				kb[3 - j] = (key[i*8 + j*2] << 8) | key[i*8 + j*2 + 1];
			
			scheduleBuild( kb, i*8, ice_keyrot[0..8] );
			scheduleBuild( kb, keysched.length - 8 - i*8, ice_keyrot[8..$] );
		}
	}
	
	
	/// Encrypt a block of 8 bytes of data with the given ICE key
	void encrypt( const ubyte[] ptext, ubyte[] ctext )
	{
		uint l, r;
		
		l =   ((cast(uint) ptext[0]) << 24)
			| ((cast(uint) ptext[1]) << 16)
			| ((cast(uint) ptext[2]) <<  8) | ptext[3];
		r =   ((cast(uint) ptext[4]) << 24)
			| ((cast(uint) ptext[5]) << 16)
			| ((cast(uint) ptext[6]) <<  8) | ptext[7];
		
		for( int i = 0; i < keysched.length; i += 2 )
		{
			l ^= ice_f( r, keysched[i] );
			r ^= ice_f( l, keysched[i+1] );
		}
		
		for (int i = 0; i < 4; i++)
		{
			ctext[3 - i] = r & 0xff;
			ctext[7 - i] = l & 0xff;
		
			r >>= 8;
			l >>= 8;
		}
	}
	
	
	/// Decrypt a block of 8 bytes of data with the given ICE key
	void decrypt( const ubyte[] ctext, ubyte[] ptext )
	{
		uint l, r;
		
		l =   ((cast(uint) ctext[0]) << 24)
			| ((cast(uint) ctext[1]) << 16)
			| ((cast(uint) ctext[2]) <<  8) | ctext[3];
		r =   ((cast(uint) ctext[4]) << 24)
			| ((cast(uint) ctext[5]) << 16)
			| ((cast(uint) ctext[6]) <<  8) | ctext[7];
		
		for( int i = keysched.length - 1; i > 0; i -= 2 )
		{
			l ^= ice_f( r, keysched[i] );
			r ^= ice_f( l, keysched[i-1] );
		}
		
		for( int i = 0; i < 4; i++ )
		{
			ptext[3 - i] = r & 0xff;
			ptext[7 - i] = l & 0xff;
		
			r >>= 8;
			l >>= 8;
		}
	}
	
	
	/// Return the key size, in bytes
	int keySize( )
	{
		return size * 8;
	}
	
	
	private:
	
	// Set 8 rounds [n, n+7] of the key schedule of an ICE key
	void scheduleBuild( ref ushort[4] kb, uint n, const int[] keyrot )
	{
		for( int i=0; i<8; i++ )
		{
			int kr = keyrot[i];
			IceSubkey isk = keysched[n + i];
			
			for( int j=0; j<3; j++ )
				isk.val[j] = 0;
			
			for( int j=0; j<15; j++ )
			{
				uint curr_sk_pos = j % 3;
				
				for( int k=0; k<4; k++ )
				{
					uint curr_kb_pos = (kr + k) & 3;
					int bit = kb[curr_kb_pos] & 1;
					
					isk.val[curr_sk_pos] = (isk.val[curr_sk_pos] << 1) | bit;
					kb[curr_kb_pos] = cast(ushort)((kb[curr_kb_pos] >> 1) | ((bit ^ 1) << 15));
				}
			}
			
			keysched[n + i] = isk;
		}
	}
	
	uint size;
	IceSubkey[] keysched;
}
